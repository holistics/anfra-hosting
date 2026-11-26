# anfra, with a login page in front, in one container.
# Put this file and deploy/start.sh at the root of your anfra project (next to models/, datasets/, apps/).
FROM docker.io/library/caddy:2.11.9 AS caddy
FROM ghcr.io/tinyauthapp/tinyauth:v5.2.0 AS tinyauth

# Use the same anfra version as the CLI you build your project with.
FROM ghcr.io/holistics/anfra:0.24.0
COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY --from=tinyauth /tinyauth/tinyauth /usr/local/bin/tinyauth
COPY --chown=anfra:anfra . /repo
EXPOSE 8080
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/bin/bash", "/repo/deploy/start.sh"]
