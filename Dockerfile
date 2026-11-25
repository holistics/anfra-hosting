# anfra, with a login page in front, in one container.
# Put this file at the root of your anfra project (next to models/, datasets/, apps/).
FROM docker.io/library/caddy:2.11.9 AS caddy
FROM ghcr.io/tinyauthapp/tinyauth:v5.2.0 AS tinyauth

FROM ghcr.io/holistics/anfra:0.24.0
COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY --from=tinyauth /tinyauth/tinyauth /usr/local/bin/tinyauth
COPY --chown=anfra:anfra . /repo
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/repo/deploy/start.sh"]
