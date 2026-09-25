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

### Passwordless sign-in email

The login page supports both the existing password flow and one-time magic
links. Magic-link tokens are stored as SHA-256 hashes, expire after 30 minutes,
and are consumed once. Development uses Swoosh's local in-memory mailbox;
tests use the Swoosh test adapter.

Production uses Swoosh SMTP. Set these environment variables:

```text
MAILER_FROM             # required sender address
MAILER_FROM_NAME        # optional, defaults to AgentYard
SMTP_RELAY              # required SMTP hostname
SMTP_USERNAME           # required SMTP username
SMTP_PASSWORD           # required SMTP password
SMTP_PORT               # optional, defaults to 587
SMTP_TLS                # optional, defaults to always
SMTP_AUTH               # optional, defaults to always
SMTP_SSL                # optional, defaults to false; use for implicit TLS
```

Set `PHX_HOST` to the public HTTPS hostname so links point to the deployed
AgentYard instance. For implicit TLS on port 465, set `SMTP_SSL=true` and
`SMTP_TLS=never`.

## What is implemented

- Phoenix Endpoint, LiveView UI and responsive light theme for Runs, New run,
  Run detail, Repositories, Agent profiles and Team settings.
- Ecto/Postgres schemas for users, teams, memberships, repositories, profiles,
  secrets, sessions, runs and normalized event logs.
- Password authentication, team membership roles (`owner`, `admin`, `member`),
  session auth, passwordless magic-link login, personal bearer API tokens and
  team-scoped authorization.
- OTP `DynamicSupervisor` plus a per-run `GenServer`, PubSub timeline updates
  and an Oban worker boundary for queued runs.
- Normalized agent adapter behaviour with fake/scripted, Claude Code,
  Cursor CLI (`cursor-agent` or `agent`) and OpenRouter adapters.
- Claude/Cursor line-delimited stream JSON parsing with recorded event
  fixtures in `test/fixtures`.
- Per-run local and Docker sandbox preparation with resource defaults, plus Git
  provider behaviours for GitHub pull requests and GitLab merge requests.
- AES-256-GCM encrypted, write-only secrets and redaction-safe event payloads.
- REST create/get/list/follow-up/cancel/event endpoints, persisted event
  history and an SSE stream with `Last-Event-ID` support.
- A checked-in OpenAPI document at `/api/openapi.yaml`.
- Docker Compose, Dockerfile, a pinned runner image skeleton
  (`Dockerfile.runner`) and GitHub Actions checks.

## Deliberate boundaries

The Fake adapter is fully end-to-end without model or forge credentials.
Claude Code, Cursor CLI and OpenRouter use the same run path and receive
profile settings plus scoped team/repository environment values, but their
CLI binaries and provider credentials must still be installed/configured by
the operator. GitHub/GitLab clone, branch, commit/push and PR/MR orchestration
is wired; runs without forge tokens emit a clear skip event instead of
attempting a write.

Docker runs default to a deny-all network. An allowlist must be resolved by an
explicit operator policy hook that returns an egress-controlled Docker network;
AgentYard never falls back to unrestricted bridge networking. Image builds
from repository configuration and persistent follow-up volumes still need
hardening. Webhook signature, fail-closed fork/mention policy, label dispatch,
and best-effort progress/result comments are wired; GitHub App installation UX
and live forge permission lookups remain outside this milestone. Persisted
workspace diffs, repository/session usage APIs, profile MCP configuration, and
pinned Claude/Cursor runner binaries are included. SSO, invitation email, CI
feedback loops, audit exports and remote/Kubernetes runners remain out of this
milestone.

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
[`docs/FEATURES.csv`](docs/FEATURES.csv). Next increments should add GitHub
App installation and live forge permission lookups, then complete Docker
environment builds, provider credentials, invitations/audit exports, and
GitLab self-managed validation. Slack/Jira triggers, OIDC/SAML, remote runner
pools, Helm and richer review workflows follow in v1.

Product and technical rationale: [`docs/CONCEPT.md`](docs/CONCEPT.md).

## Implementation status

The current MVP gap map is tracked in
[`docs/IMPLEMENTATION-TODO.md`](docs/IMPLEMENTATION-TODO.md). Remaining
boundaries are deliberate: forge App installation and live permission APIs,
operator-provided Docker egress policy, ACP runtime transport, and audit
exports.
Static visual references: [`docs/prototype/`](docs/prototype/).
