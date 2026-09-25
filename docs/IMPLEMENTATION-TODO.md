# AgentYard MVP implementation checklist

This is the 57-item execution checklist for the MVP gaps, ordered by sprint.
The status reflects the code in this branch; `Done` means the path is wired in
the control plane, while `Partial` means an integration boundary or production
hardening remains.

## Sprint A — run execution

| ID | MVP item | Status |
|---|---|---|
| M01 | Start a run from the New-run LiveView | Done |
| M02 | Start a run through REST | Done |
| M03 | Read team and repository secrets from the encrypted vault | Done |
| M04 | Inject scoped secret values into adapter environments | Done |
| M05 | Mask secret values in persisted and broadcast events | Done |
| M06 | Prepare a per-run Local workspace | Done |
| M07 | Prepare a per-run Docker workspace | Done |
| M08 | Apply CPU, memory, default-deny network, and allowlist hook settings | Partial |
| M09 | Clone the repository and check out the requested ref | Done |
| M10 | Create the generated agent branch | Done |
| M11 | Persist the New-run `auto_pr` choice | Done |
| M12 | Open GitHub pull requests after successful runs | Done |
| M13 | Open GitLab merge requests after successful runs | Done |
| M14 | Keep Fake runs usable without forge credentials | Done |
| M15 | Forward permission mode to adapters | Done |
| M16 | Forward profile instructions to adapters | Done |
| M17 | Forward model, BYO keys, and OpenAI-compatible base URL | Done |
| M18 | Stop a run when reported usage exceeds its USD budget | Done |
| M19 | Enqueue execution through an Oban worker | Done |
| M20 | Enforce a basic team and per-session concurrency cap | Done |

## Sprint B — forge triggers

| ID | MVP item | Status |
|---|---|---|
| M21 | Verify GitHub webhook signatures | Partial |
| M22 | Verify GitLab webhook tokens/signatures | Partial |
| M23 | Trigger runs from GitHub @mentions | Partial |
| M24 | Trigger runs from GitHub labels | Partial |
| M25 | Trigger runs from GitLab @mentions | Partial |
| M26 | Trigger runs from GitLab labels | Partial |
| M27 | Post progress comments to the source issue or PR | Done |
| M28 | Post result comments with the PR/MR link | Done |
| M29 | Reject fork pull requests without a trusted workspace | Partial |
| M30 | Check mentioner write permission and document token-based App boundary | Partial |

## Sprint C — lifecycle and governance

| ID | MVP item | Status |
|---|---|---|
| M31 | Enforce a wall-clock timeout | Done |
| M32 | Enforce a maximum-turn limit | Done |
| M33 | Steer a running agent with a follow-up | Done |
| M34 | Enforce `Accounts.authorize` on mutating UI/API operations | Done |
| M35 | Keep run visibility member-only or add a viewer role | Done |
| M36 | Record a basic audit event for mutations | Done |
| M37 | Keep magic-link authentication deferred with an explicit boundary | Partial |
| M38 | Preserve explicit queued/running/succeeded/failed/cancelled state transitions | Done |
| M39 | Retry provisioning failures without replaying agent turns | Partial |
| M40 | Clean up sandbox resources after terminal states | Partial |

## Sprint D — inspection and API

| ID | MVP item | Status |
|---|---|---|
| M41 | Show terminal output from normalized tool-result events | Done |
| M42 | Show a real workspace diff | Partial |
| M43 | Filter runs by status and prompt | Done |
| M44 | Expose `GET /api/repositories` | Partial |
| M45 | Expose a per-run and session usage endpoint | Partial |
| M46 | Pass configured MCP servers through to adapters | Partial |
| M47 | Define an ACP adapter boundary | Partial |
| M48 | Show setup and sandbox progress in the timeline | Done |
| M49 | Preserve run event history and resumable SSE | Done |
| M50 | Keep OpenAPI documentation aligned with added endpoints | Partial |

## Runner, tests, and documentation

| ID | MVP item | Status |
|---|---|---|
| M51 | Add a pinned runner image skeleton for Claude Code and Cursor CLI | Partial |
| M52 | Test scoped secret injection and redaction | Partial |
| M53 | Test forge orchestration with provider stubs | Partial |
| M54 | Test Oban enqueue and worker behavior | Partial |
| M55 | Test budget hard-stop behavior | Partial |
| M56 | Test webhook signature verification | Partial |
| M57 | Keep the README boundaries, Apache-2.0 license, and PR checklist current | Partial |

### Implementation notes

The first complete slice is Sprint A. Forge publication intentionally becomes
a clear status event when a token is absent, so the Fake adapter remains
usable in a fresh development database. Sprint B now includes signed webhook
dispatch and best-effort issue/PR comments; GitHub App installation UX and
live forge permission lookups remain open. Domain-level allowlist enforcement,
durable diffs, MCP/ACP passthrough, and the remaining Sprint D items are
follow-up work rather than silent no-ops.
