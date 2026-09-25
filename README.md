# AgentYard

AgentYard is an Apache-2.0, self-hosted control plane for team coding agents.

It gives teams one place to start, observe and steer repository runs while
keeping repositories, credentials and model keys on infrastructure they
control.

This repository is the first walking skeleton: Phoenix/LiveView, Postgres,
Oban and OTP processes are connected through a real run/event lifecycle. The
fake adapter makes the product usable without an LLM key and is the default
for the seeded demo.

## Quickstart with Docker Compose

```sh
docker compose up --build
```

Open <http://localhost:4000>. Development demo mode provides:

- `demo@agentyard.local`
- `demo-password`

The seed creates an Acme Engineering team, a fake agent profile, a connected
example repository and a run that streams through the run detail timeline.
The compose secrets are development-only; replace them before deployment.

To run the Elixir checks locally:

```sh
mix deps.get
mix test
```

The test suite does not require a running Postgres instance for unit tests.
CI additionally creates and migrates a Postgres database.

## Production deploy

Production images are published to
`ghcr.io/dominicletz/agentyard:<tag>`. The image workflow publishes both the
commit SHA tag and `:main` on pushes to `main` (and can also be run manually).
The production image runs database migrations before starting the Phoenix
release.

The deploy workflow runs after a successful image build for `main`, or can be
started manually with either `main` or a commit SHA as the image tag. Configure
these GitHub Actions secrets:

- `DEPLOY_HOST` — SSH hostname or address.
- `DEPLOY_USER` — SSH user with access to the deployment directory and Docker.
- `DEPLOY_SSH_KEY` — private key for that user.
- `DEPLOY_PORT` — optional SSH port, default `22`.
- `DEPLOY_PATH` — optional remote directory, default `/opt/agentyard`.

If the GHCR package is private, also configure `GHCR_USERNAME` and a
`GHCR_TOKEN` with permission to read packages, or log in to GHCR on the server
during bootstrap. The workflow never copies or replaces the server's `.env`;
it copies the production Compose files and `.env.prod.example` on each deploy
so those files stay in sync.

The server needs Docker, the Docker Compose plugin, and an SSH user in the
`docker` group. A first-time setup is:

1. Create the deployment user and `/opt/agentyard` (or the configured path).
2. Copy or clone `docker-compose.prod.yml`, `Caddyfile`, and
   `.env.prod.example` into that directory.
3. Copy `.env.prod.example` to `.env` and replace all `CHANGE_ME` values. For
   example, generate `SECRET_KEY_BASE` with `openssl rand -hex 64` and
   `AGENTYARD_SECRET_KEY` with `openssl rand -hex 32`.
4. Pull and start the stack:

   ```sh
   docker compose -f docker-compose.prod.yml pull
   docker compose -f docker-compose.prod.yml up -d
   ```

Set `COMPOSE_PROFILES=caddy` in `.env` (or add `--profile caddy`) and set
`DOMAIN` when the server should run the optional Caddy service. With DNS
pointing at the server and ports 80/443 open, Caddy obtains and renews the
Let's Encrypt certificate and proxies to the app on port 4000.

Set `DEMO_MODE=false` in production. The seeded demo account
(`demo@agentyard.local` / `demo-password`) is for local development only and
must not be enabled on a production deployment.

## What is implemented

- Phoenix Endpoint, LiveView UI and responsive light theme for Runs, New run,
  Run detail, Repositories, Agent profiles and Team settings.
- Ecto/Postgres schemas for users, teams, memberships, repositories, profiles,
  secrets, sessions, runs and normalized event logs.
- Password authentication, team membership roles (`owner`, `admin`, `member`),
  session auth, personal bearer API tokens and team-scoped authorization.
- OTP `DynamicSupervisor` plus a per-run `GenServer`, PubSub timeline updates
  and an Oban worker boundary for queued runs.
- Normalized agent adapter behaviour with fake/scripted, Claude Code,
  Cursor CLI (`cursor-agent` or `agent`) and OpenRouter adapters.
- Claude/Cursor line-delimited stream JSON parsing with recorded event
  fixtures in `test/fixtures`.
- Pluggable local and Docker sandbox behaviours, plus Git provider behaviours
  for GitHub pull requests and GitLab merge requests.
- AES-256-GCM encrypted, write-only secrets and redaction-safe event payloads.
- REST create/get/list/follow-up/cancel/event endpoints, persisted event
  history and an SSE stream with `Last-Event-ID` support.
- A checked-in OpenAPI document at `/api/openapi.yaml`.
- Docker Compose, Dockerfile and GitHub Actions checks.

## Deliberate boundaries of this first PR

The fake adapter is the only fully end-to-end provider in the seeded flow.
Claude Code, Cursor CLI and OpenRouter adapters are implemented behind the
same interface, but production images still need their CLI/key configuration.
The GitHub/GitLab providers expose clone, branch, commit/push and PR/MR
operations, but automatic forge orchestration and webhook/@mention triggers
are next-step work. Docker and local runners are pluggable foundations;
wiring repository environment builds and strict network policy into every run
is not yet complete. SSO, invitation email, auditing UI, CI feedback loops and
remote/Kubernetes runners remain roadmap items.

## Architecture

```text
LiveView / REST + SSE
        │
Accounts · Repositories · Profiles · Secrets · Runs
        │
Oban queue ── DynamicSupervisor ── RunProcess
                                      ├─ Adapter (Fake / Claude / Cursor / OpenRouter)
                                      ├─ Sandbox behaviour (Local / Docker)
                                      └─ Git provider behaviour (GitHub / GitLab)
        │
Postgres: sessions, runs and replayable normalized events
```

The contexts map to the concept domain model. `RunProcess` is the small OTP
boundary where an asynchronous adapter callback becomes a persisted event and
a PubSub update. A future runner can replace the Docker implementation
without changing LiveViews or API clients.

## API

Create an API token in the seeded database or from the Accounts context, then:

```sh
curl -H "Authorization: Bearer ay_..." http://localhost:4000/api/runs
curl -N -H "Authorization: Bearer ay_..." \
  http://localhost:4000/api/runs/RUN_ID/events/stream
```

See [`priv/static/openapi.yaml`](priv/static/openapi.yaml) or
`http://localhost:4000/api/openapi.yaml` for the endpoint contract.

## Roadmap

The complete catalog is in [`docs/FEATURES.md`](docs/FEATURES.md) and
[`docs/FEATURES.csv`](docs/FEATURES.csv). Next increments should wire
forge-native webhooks and safe clone/branch/PR orchestration, then complete
Docker environment builds, provider credentials, invitations/audit events,
and GitLab self-managed validation. Slack/Jira triggers, OIDC/SAML, remote
runner pools, Helm and richer review workflows follow in v1.

Product and technical rationale: [`docs/CONCEPT.md`](docs/CONCEPT.md).
Static visual references: [`docs/prototype/`](docs/prototype/).
