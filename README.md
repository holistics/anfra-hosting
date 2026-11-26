# anfra self-host

Run your [anfra](https://github.com/holistics/anfra) project behind a login page, on Render or any host that runs Docker containers, for your team and your coding agents.

You don't add anything to your project. You deploy this repo, tell it where your project is on GitHub, and it pulls your project when it starts, then every minute. Push to your project, and the change shows up without a redeploy.

Without a project, it serves a small sample with its own DuckDB database, so you can try it first.

## Self-host on Render

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy?repo=https://github.com/holistics/anfra-render-test)

1. Click **Deploy to Render**.
2. Fill in:
   - **LOGIN_USERS**: who can sign in, as `name:password` pairs separated by commas. Add a user named `agent` for your coding agent.
   - **ANFRA_PROJECT_REPO**: your project's GitHub repo, such as `your-org/your-project`. Leave it empty to try the sample.
   - **ANFRA_PROJECT_TOKEN**: for a private repo only, a token that can read it. See [Private repos](#private-repos).
3. Approve the deploy. When it finishes, open the link Render shows and sign in.

**Your database:** in the service's **Environment** tab, add `ANFRA_DATA_SOURCES` with the contents of your `.anfra/data_sources.yml`. A project that only uses a DuckDB file in its repo doesn't need it.

For other hosts, follow their page in the guide: [Railway](https://anfra.ai/docs/self-host/railway), [Fly.io](https://anfra.ai/docs/self-host/fly), [DigitalOcean](https://anfra.ai/docs/self-host/digitalocean), [Heroku](https://anfra.ai/docs/self-host/heroku), [Google Cloud Run](https://anfra.ai/docs/self-host/cloud-run), [Azure](https://anfra.ai/docs/self-host/azure), [AWS](https://anfra.ai/docs/self-host/aws), or [your own server](https://anfra.ai/docs/self-host/own-server).

## Private repos

anfra needs a token that can read your project, and nothing more. On GitHub: **Settings** > **Developer settings** > **Personal access tokens** > **Fine-grained tokens** > **Generate new token**. Pick your project's repo under **Only select repositories**, and give it **Contents: Read-only**. If an organization owns the repo, it may need to approve the token.

The token stays in your host's settings. It is never written to disk in the container.

## Settings

| Env Var | Purpose |
| --- | --- |
| `LOGIN_USERS` | Who can sign in, as `name:password` pairs separated by commas |
| `ANFRA_PROJECT_REPO` | Your project's repo: `owner/name` on GitHub, or a full git URL. Empty serves the sample. |
| `ANFRA_PROJECT_TOKEN` | A token that can read a private repo |
| `ANFRA_PROJECT_BRANCH` | The branch to serve. Default: the repo's default branch. |
| `ANFRA_PROJECT_PATH` | The folder of the anfra project inside the repo, when it isn't the root |
| `ANFRA_PROJECT_SYNC_SECONDS` | How often to pull new commits. Default: `60`. `0` turns it off. |
| `ANFRA_DATA_SOURCES` | The contents of your `.anfra/data_sources.yml`. Without it, anfra uses the project's `.anfra/data_sources.yml.example`. |
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
| `render.yaml` | Render: the Blueprint behind the button. |
| `fly.toml` | Fly.io: one machine with 512 MB, kept running, checked on `/health`. |
| `heroku.yml` | Heroku: builds the `Dockerfile` on the container stack. |
| `.do/deploy.template.yaml` | DigitalOcean App Platform: the app spec. |
| `compose.yaml`, `.env.example` | Your own server, with Docker Compose. |
| `models/`, `datasets/`, `apps/`, `example-data/` | The sample project, served when `ANFRA_PROJECT_REPO` is empty. |
| `.github/smoke-test.sh` | Builds the image and checks it: sign-in, a coding agent over MCP, a query, your project from git, the error messages. CI runs it on every push and every week. |
