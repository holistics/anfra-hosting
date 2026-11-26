# anfra, with a login page in front, in one container.
# Serves your anfra project from ANFRA_PROJECT_REPO, or else the sample project in this repo.
FROM docker.io/library/caddy:2.11.9 AS caddy
FROM ghcr.io/tinyauthapp/tinyauth:v5.2.0 AS tinyauth

# Use the same anfra version as the CLI you build your project with.
FROM ghcr.io/holistics/anfra:0.24.0
USER root
# git: to clone your project from ANFRA_PROJECT_REPO and keep it up to date.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git ca-certificates \
  && rm -rf /var/lib/apt/lists/*
USER anfra
COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY --from=tinyauth /tinyauth/tinyauth /usr/local/bin/tinyauth
COPY --chown=anfra:anfra . /repo
EXPOSE 8080
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/bin/bash", "/repo/deploy/start.sh"]
