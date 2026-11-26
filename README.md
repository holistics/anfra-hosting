# anfra-hosting

The Docker image to self-host an [anfra](https://github.com/holistics/anfra) project behind a login page, `ghcr.io/holistics/anfra-hosting`, and the files a project needs to use it.

Follow the guide for your host at [anfra.ai/docs/self-host](https://anfra.ai/docs/self-host).

## Add it to your project

From your project's folder, run:

```bash
curl -fsSL -O https://raw.githubusercontent.com/holistics/anfra-hosting/main/Dockerfile \
  -O https://raw.githubusercontent.com/holistics/anfra-hosting/main/.dockerignore
git add Dockerfile .dockerignore
git commit -m "Add Dockerfile"
git push
```

On Heroku, download `heroku.yml` too. Then deploy on your host and set `LOGIN_USERS`.

## Settings

The login is on by default. Without `LOGIN_USERS`, Google or GitHub sign-in, or `LOGIN_DISABLED=true`, the container stops and its logs say what to set.

| Env Var | Purpose |
| --- | --- |
| `LOGIN_USERS` | Who can sign in, as `name:password` pairs separated by commas |
| `ANFRA_DATA_SOURCES` | The contents of your `.anfra/data_sources.yml`. A file mounted at `/etc/secrets/data_sources.yml` wins over it. Without either, anfra uses the project's `.anfra/data_sources.yml.example`. |
| `PUBLIC_URL` | The address people open. Render, Fly.io, Railway and Azure set it for you. |
| `LOGIN_GOOGLE_CLIENT_ID`, `LOGIN_GOOGLE_CLIENT_SECRET`, `LOGIN_GITHUB_CLIENT_ID`, `LOGIN_GITHUB_CLIENT_SECRET`, `LOGIN_ALLOWED_EMAILS` | Sign-in with Google or GitHub accounts |
| `LOGIN_DISABLED` | `true` turns off the login, when your own proxy controls access, such as Tailscale or Cloudflare Access. Anyone who can reach the address can then use anfra. |
| `LOGIN_TITLE` | The title on the login page. Default: `anfra`. |
| `LOGIN_BACKGROUND` | The login page's background: `paper` (default), `ink`, or the URL of your own image |
| `PORT` | The port to listen on. Default: `8080`. |
| `ANFRA_PROJECT_REPO`, `ANFRA_PROJECT_TOKEN`, `ANFRA_PROJECT_BRANCH`, `ANFRA_PROJECT_PATH`, `ANFRA_PROJECT_SYNC_SECONDS` | Serve a project from a git repo instead of the one copied into the image, and pull its new commits every minute |

See [Authentication](https://anfra.ai/docs/self-host/authentication) for each sign-in option.

## What's in here

| Path | What it is |
| --- | --- |
| `Dockerfile` | The 2 lines a project needs: the image, plus the project copied in |
| `.dockerignore` | Keeps database credentials out of the image |
| `heroku.yml` | Heroku's build config |
| `image/` | The image's source: its `Dockerfile`, `start.sh`, and the login page backgrounds |
| `test/` | `smoke-test.sh`, and the sample project it deploys |

## Change the image

1. Edit `image/`.
2. Check it: `test/smoke-test.sh`, or `DOCKER=podman test/smoke-test.sh`. It builds the image and checks sign-in, a coding agent over MCP, a query, the login turned off, Google and GitHub sign-in, and the error messages.
3. Publish it, with a GitHub token that has `write:packages`:

   ```bash
   docker build -t ghcr.io/holistics/anfra-hosting:0.24.0 image
   docker push ghcr.io/holistics/anfra-hosting:0.24.0
   ```

The tag is the anfra version the image is built on. To move to a new anfra version, change it in `image/Dockerfile`, in `Dockerfile`, and in `test/smoke-test.sh`.
