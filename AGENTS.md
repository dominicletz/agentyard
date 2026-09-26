# AgentYard agent guide

AgentYard is a self-hosted Elixir/Phoenix control plane for team coding
agents. It lets teams start, observe, and steer repository runs on
infrastructure they control.

## Start here

- Follow [`docs/STYLE_GUIDE.md`](docs/STYLE_GUIDE.md) for the visual language,
  tokens, UI patterns, and brand usage.
- Brand assets live in [`priv/static/images/`](priv/static/images/); CSS lives
  in [`priv/static/css/`](priv/static/css/).
- Keep changes focused, reuse existing components and tokens, and preserve
  accessible labels, keyboard focus, and CSRF protection.

## Development

The application uses Elixir, Phoenix, Phoenix LiveView, Ecto/Postgres, and
Oban. For the normal local stack:

```sh
docker compose up --build
```

The seeded demo login is documented in [`README.md`](README.md):
`demo@agentyard.local` / `demo-password`. For a dependency-only setup, run
`mix deps.get`; use the repository's configured environment variables rather
than committing local secrets.

Before pushing, run the same static checks as
[`.github/workflows/ci.yml`](.github/workflows/ci.yml):

```sh
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict
```

Use Phoenix conventions for controllers and HEEx, keep LiveViews thin around
context operations, and respect Oban's worker/queue boundaries. Put domain
logic in contexts or supervised processes rather than templates or
controllers.

## Testing

Run the full suite with:

```sh
mix test
```

CI provisions Postgres and sets `DATABASE_URL` before creating and migrating
the test database. Keep controllers, LiveViews, and contexts covered. Prefer
`ConnCase` for HTML/controller assertions; auth tests should verify the root
layout and stylesheet links, not just inner text. Store reusable fixtures in
[`test/fixtures/`](test/fixtures/).

Never commit passwords, API keys, tokens, `.env` files, or generated secret
material.

## Documentation map

- [`README.md`](README.md) — quickstart, deployment, and API overview
- [`docs/CONCEPT.md`](docs/CONCEPT.md) — product and technical rationale
- [`docs/FEATURES.md`](docs/FEATURES.md) / [`docs/FEATURES.csv`](docs/FEATURES.csv)
  — feature catalog
- [`docs/IMPLEMENTATION-TODO.md`](docs/IMPLEMENTATION-TODO.md) — MVP gap map
- [`docs/STYLE_GUIDE.md`](docs/STYLE_GUIDE.md) — UI tokens and patterns
- [`docs/prototype/`](docs/prototype/) — static visual references
- [`priv/static/openapi.yaml`](priv/static/openapi.yaml) — API contract

## Security basics

Do not bake `.env` files or secrets into images or commits. Production secrets
are runtime-only and must be supplied through the deployment environment.
Keep `DEMO_MODE=false` in production; demo credentials are for local
development only.
