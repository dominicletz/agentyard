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
[`docs/FEATURES.csv`](docs/FEATURES.csv). Next increments should wire
forge-native webhooks and safe clone/branch/PR orchestration, then complete
Docker environment builds, provider credentials, invitations/audit events,
and GitLab self-managed validation. Slack/Jira triggers, OIDC/SAML, remote
runner pools, Helm and richer review workflows follow in v1.

Product and technical rationale: [`docs/CONCEPT.md`](docs/CONCEPT.md).

## Implementation status

The current MVP gap map is tracked in
[`docs/IMPLEMENTATION-TODO.md`](docs/IMPLEMENTATION-TODO.md). Remaining
boundaries are deliberate: forge App installation and live permission APIs,
operator-provided Docker egress policy, ACP, magic links, retry/cleanup
hardening, and audit exports.
Static visual references: [`docs/prototype/`](docs/prototype/).
