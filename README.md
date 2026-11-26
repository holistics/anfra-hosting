# anfra on Render

An [anfra](https://github.com/holistics/anfra) sample project, ready to self-host on [Render](https://render.com) behind a login page. It has a small DuckDB database, so it runs with no setup.

1. Click **Use this template** to copy this repo to your account.
2. In the [Render dashboard](https://dashboard.render.com), click **New**, then **Blueprint**, and connect your copy.
3. Fill in **LOGIN_USERS**: who can sign in, as `name:password` pairs separated by commas. Add a user named `agent` for your coding agent.
4. Click **Deploy Blueprint**. When it finishes, open the link Render shows and sign in.

The full guide, including connecting your coding agent and using your own database, is at [anfra.ai/docs/self-host/render](https://anfra.ai/docs/self-host/render).

## What's in here

| Path | What it is |
| --- | --- |
| `models/`, `datasets/`, `apps/`, `example-data/` | The sample project. Replace them with your own. |
| `render.yaml` | The Render Blueprint: how Render runs anfra, and what it asks for. |
| `Dockerfile`, `deploy/` | anfra with a login page ([tinyauth](https://tinyauth.app)) and a web server ([Caddy](https://caddyserver.com)) in one container. |

Never commit `.anfra/data_sources.yml`: it holds your database credentials. `.gitignore` already keeps it out.
