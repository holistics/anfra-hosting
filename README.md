# anfra self-host template

An [anfra](https://github.com/holistics/anfra) sample project, ready to self-host behind a login page on any host that runs Docker containers. Its small DuckDB database needs no setup, so it runs as soon as you deploy it.

Use it two ways:

- **Try it:** copy this repo with **Use this template**, and deploy your copy.
- **Self-host your own project:** download the files below into your project.

The full guide is at [anfra.ai/docs/self-host](https://anfra.ai/docs/self-host).

## Try it on Render

1. Click **Use this template** to copy this repo to your account.
2. In the [Render dashboard](https://dashboard.render.com), click **New**, then **Blueprint**, and connect your copy.
3. Fill in **LOGIN_USERS**: who can sign in, as `name:password` pairs separated by commas. Add a user named `agent` for your coding agent.
4. Click **Deploy Blueprint**. When it finishes, open the link Render shows and sign in.

For other hosts, follow their page in the guide: [Railway](https://anfra.ai/docs/self-host/railway), [Fly.io](https://anfra.ai/docs/self-host/fly), [DigitalOcean](https://anfra.ai/docs/self-host/digitalocean), [Heroku](https://anfra.ai/docs/self-host/heroku), [Google Cloud Run](https://anfra.ai/docs/self-host/cloud-run), [Azure](https://anfra.ai/docs/self-host/azure), [AWS](https://anfra.ai/docs/self-host/aws), or [your own server](https://anfra.ai/docs/self-host/own-server).

## Self-host your own project

From your project's root folder, download the `Dockerfile`, `deploy/start.sh`, and your host's file:

```bash
base=https://raw.githubusercontent.com/holistics/anfra-render-test/main
mkdir -p deploy
curl -fsSLo Dockerfile "$base/Dockerfile"
curl -fsSLo deploy/start.sh "$base/deploy/start.sh"
curl -fsSLO "$base/render.yaml"   # or fly.toml, heroku.yml, compose.yaml
```

Add these lines to your `.dockerignore`, so your credentials stay out of the image:

```text
.anfra/data_sources.yml
.env
```

Then set `LOGIN_USERS` on your host, and `ANFRA_DATA_SOURCES` to the contents of your `.anfra/data_sources.yml`.

## What's in here

| Path | What it is |
| --- | --- |
| `models/`, `datasets/`, `apps/`, `example-data/` | The sample project. Replace them with your own. |
| `Dockerfile`, `deploy/start.sh` | anfra with a login page ([tinyauth](https://tinyauth.app)) and a web server ([Caddy](https://caddyserver.com)) in one container. |
| `render.yaml` | Render: the Blueprint. |
| `fly.toml` | Fly.io: one machine with 512 MB, kept running, checked on `/health`. |
| `heroku.yml` | Heroku: builds the `Dockerfile` on the container stack. |
| `.do/deploy.template.yaml` | DigitalOcean App Platform: the app spec. |
| `compose.yaml`, `.env.example` | Your own server, with Docker Compose. |
| `.github/smoke-test.sh` | Builds the image and checks it: sign-in, a coding agent over MCP, a query, the error messages. CI runs it on every push and every week. |

## Settings

| Env Var | Purpose |
| --- | --- |
| `LOGIN_USERS` | Who can sign in, as `name:password` pairs separated by commas |
| `ANFRA_DATA_SOURCES` | The contents of your `.anfra/data_sources.yml`. Without it, anfra uses `.anfra/data_sources.yml.example`, which is enough for this sample. |
| `PUBLIC_URL` | The address people open. Render, Fly.io, Railway and Azure set it for you. |
| `LOGIN_GOOGLE_CLIENT_ID`, `LOGIN_GOOGLE_CLIENT_SECRET`, `LOGIN_GITHUB_CLIENT_ID`, `LOGIN_GITHUB_CLIENT_SECRET`, `LOGIN_ALLOWED_EMAILS` | Sign-in with Google or GitHub accounts |
| `LOGIN_DISABLED` | `true` turns off the login page, when your own proxy signs people in, such as Tailscale or Cloudflare Access |
| `PORT` | The port to listen on. Default: `8080`. |
| `LOGIN_TITLE` | The title on the login page. Default: `anfra`. |

See [Authentication](https://anfra.ai/docs/self-host/authentication) for each option.

Never commit `.anfra/data_sources.yml` or `.env`: they hold your credentials. `.gitignore` already keeps them out.
