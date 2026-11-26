# anfra self-host

Run your [anfra](https://github.com/holistics/anfra) project behind a login page on any host that runs Docker containers, for your team and your coding agents.

You don't add anything to your project. You deploy this repo, tell it where your project is on GitHub, and it pulls your project when it starts, then every minute. Push to your project, and the change shows up without a redeploy.

Without a project, it serves a small sample with its own DuckDB database, so you can try it first.

## Self-host your project

1. **Push your project to GitHub.** Keep `.anfra/data_sources.yml` out of git: `anfra init` already ignores it.
2. **Copy this repo** with **Use this template**, or fork it.
3. **Deploy your copy** on your host. Most hosts build its `Dockerfile` straight from GitHub. See [Hosts](#hosts).
4. **Set the variables** on your host:
   - `LOGIN_USERS`: who can sign in, as `name:password` pairs separated by commas. Add a user named `agent` for your coding agent.
   - `ANFRA_PROJECT_REPO`: your project's repo, such as `your-org/your-project`.
   - `ANFRA_PROJECT_TOKEN`: for a private repo only, a token that can read it. See [Private repos](#private-repos).
   - `ANFRA_DATA_SOURCES`: the contents of your `.anfra/data_sources.yml`. A project that only uses a DuckDB file in its repo doesn't need it.
   - `PUBLIC_URL`: the address people open, such as `https://data.example.com`. Render, Fly.io, Railway and Azure set it for you.
5. **Open the address** and sign in.

The container needs at least 512 MB of memory, one instance (with more, sign-in breaks), HTTPS from the host, and `/health` as its health check.

## Hosts

| Host | How | Config in this repo | Guide |
| --- | --- | --- | --- |
| Render | **New** > **Blueprint**, connect your copy | `render.yaml` | [Render](https://anfra.ai/docs/self-host/render) |
| Railway | **New Project** > **Deploy from GitHub repo** | | [Railway](https://anfra.ai/docs/self-host/railway) |
| Fly.io | `fly launch --no-deploy`, `fly secrets set`, `fly deploy --ha=false` | `fly.toml` | [Fly.io](https://anfra.ai/docs/self-host/fly) |
| DigitalOcean | **Create** > **App Platform**, connect your copy | `.do/deploy.template.yaml` | [DigitalOcean](https://anfra.ai/docs/self-host/digitalocean) |
| Heroku | `heroku stack:set container`, `git push heroku main` | `heroku.yml` | [Heroku](https://anfra.ai/docs/self-host/heroku) |
| Google Cloud Run | `gcloud run deploy anfra --source . --min 1 --max 1` | | [Cloud Run](https://anfra.ai/docs/self-host/cloud-run) |
| Azure Container Apps | `az containerapp up --source . --target-port 8080` | | [Azure](https://anfra.ai/docs/self-host/azure) |
| AWS Lightsail | build the image, push it, deploy it | | [AWS](https://anfra.ai/docs/self-host/aws) |
| Your own server | `docker compose up -d` | `compose.yaml`, `.env.example` | [Your own server](https://anfra.ai/docs/self-host/own-server) |

### Your own server

```bash
git clone https://github.com/holistics/anfra-render-test.git anfra && cd anfra
cp .env.example .env                              # fill in the users and your project
cp ~/path/to/your-project/.anfra/data_sources.yml .   # your database credentials
docker compose up -d
```

Then put an HTTPS proxy in front of `127.0.0.1:8080`, such as Caddy, Cloudflare Tunnel or Tailscale. Sign-in only works over HTTPS.

## Private repos

anfra needs a token that can read your project, and nothing more. On GitHub: **Settings** > **Developer settings** > **Personal access tokens** > **Fine-grained tokens** > **Generate new token**. Pick your project's repo under **Only select repositories**, and give it **Contents: Read-only**. If an organization owns the repo, it may need to approve the token.

The token stays in your host's settings. The container sends it to GitHub and never writes it to disk.

## Settings

| Env Var | Purpose |
| --- | --- |
| `LOGIN_USERS` | Who can sign in, as `name:password` pairs separated by commas |
| `ANFRA_PROJECT_REPO` | Your project's repo: `owner/name` on GitHub, or a full git URL. Empty serves the sample. |
| `ANFRA_PROJECT_TOKEN` | A token that can read a private repo |
| `ANFRA_PROJECT_BRANCH` | The branch to serve. Default: the repo's default branch. |
| `ANFRA_PROJECT_PATH` | The folder of the anfra project inside the repo, when it isn't the root |
| `ANFRA_PROJECT_SYNC_SECONDS` | How often to pull new commits. Default: `60`. `0` turns it off. |
| `ANFRA_DATA_SOURCES` | The contents of your `.anfra/data_sources.yml`. A file mounted at `/etc/secrets/data_sources.yml` wins over it. Without either, anfra uses the project's `.anfra/data_sources.yml.example`. |
| `PUBLIC_URL` | The address people open. Render, Fly.io, Railway and Azure set it for you. |
| `LOGIN_GOOGLE_CLIENT_ID`, `LOGIN_GOOGLE_CLIENT_SECRET`, `LOGIN_GITHUB_CLIENT_ID`, `LOGIN_GITHUB_CLIENT_SECRET`, `LOGIN_ALLOWED_EMAILS` | Sign-in with Google or GitHub accounts |
| `LOGIN_DISABLED` | `true` turns off the login page, when your own proxy signs people in, such as Tailscale or Cloudflare Access |
| `PORT` | The port to listen on. Default: `8080`. |
| `LOGIN_TITLE` | The title on the login page. Default: `anfra`. |

See [Authentication](https://anfra.ai/docs/self-host/authentication) for each sign-in option.

## What's in here

| Path | What it is |
| --- | --- |
| `Dockerfile`, `deploy/start.sh` | anfra with a login page ([tinyauth](https://tinyauth.app)) and a web server ([Caddy](https://caddyserver.com)) in one container. It clones your project and keeps it up to date. |
| `render.yaml`, `fly.toml`, `heroku.yml`, `.do/deploy.template.yaml` | Config for hosts that read it from the repo |
| `compose.yaml`, `.env.example` | Your own server, with Docker Compose |
| `models/`, `datasets/`, `apps/`, `example-data/` | The sample project, served when `ANFRA_PROJECT_REPO` is empty |
| `.github/smoke-test.sh` | Builds the image and checks it: sign-in, a coding agent over MCP, a query, your project from git, the error messages. Run it with `.github/smoke-test.sh`. |
