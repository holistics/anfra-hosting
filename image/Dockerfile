# ghcr.io/holistics/anfra-hosting: anfra with a login page (tinyauth) and a web server (Caddy)
# in one container. A project adds its files with a 2-line Dockerfile:
#
#   FROM ghcr.io/holistics/anfra-hosting:0.24.0
#   COPY --chown=anfra:anfra . /repo
FROM docker.io/library/caddy:2.11.9 AS caddy
FROM ghcr.io/tinyauthapp/tinyauth:v5.2.0 AS tinyauth

FROM ghcr.io/holistics/anfra:0.24.0
LABEL org.opencontainers.image.source=https://github.com/holistics/anfra-render-test
LABEL org.opencontainers.image.description="anfra with a login page, ready to self-host"
USER root
# git: to serve a project from ANFRA_PROJECT_REPO and keep it up to date.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git ca-certificates \
  && rm -rf /var/lib/apt/lists/*
USER anfra
COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY --from=tinyauth /tinyauth/tinyauth /usr/local/bin/tinyauth
COPY --chmod=755 start.sh /usr/local/share/anfra-hosting/start.sh
EXPOSE 8080
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/usr/local/share/anfra-hosting/start.sh"]
