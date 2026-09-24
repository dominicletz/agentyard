# AgentYard: feature catalog

Compiled from every reference researched for `CONCEPT.md` (v2) and its appendices, with quick re-checks on 2026-09-25 against Cursor docs (Cloud Agents, Automations, Cloud Agents API, Self-Hosted Machines / Team Pools), Claude docs (Managed Agents overview, Claude Code cloud sessions, GitLab CI/CD) and Coder Agents docs.

**Rules:** no invented features. `?` after a code means presence in that reference is uncertain. `—` means no reference has it; it's an AgentYard hygiene item. Priorities follow CONCEPT.md: **MVP** = single-node Docker Compose, GitHub + GitLab (incl. self-managed), Claude Code + Cursor CLI + one OpenRouter path, web UI + REST/SSE, basic multi-user/RBAC. **v1** = the next milestone (Slack/Jira, SSO, remote runners/Helm, Codex, automations). **Later** = after v1. **Not planned** = out of scope or deliberately excluded.

**Total features: 259**, across 19 categories.

| Priority | Count |
|---|---|
| MVP | 91 |
| v1 | 86 |
| Later | 64 |
| Not planned | 18 |

## Legend

| Code | Reference |
|---|---|
| `CUR` | Cursor Cloud Agents (incl. Cloud Agents API, Automations, environment.json/Builds, Self-Hosted Machines/Team Pools, Slack/GitHub/Linear integrations) |
| `CMA` | Anthropic Claude Managed Agents (hosted harness + sandbox API) |
| `CC` | Claude Code family: CLI headless (`-p`), Agent SDK, GitHub Actions, GitLab CI/CD, cloud sessions/web, routines, Claude in Slack |
| `OH` | OpenHands OSS (MIT: Agent Canvas, CLI, SDK, agent-server, resolver) |
| `OHE` | OpenHands Cloud / Enterprise (commercial / PolyForm). Listed only where the feature is exclusive to Cloud/Enterprise; OH features are also in OHE |
| `CAM` | Camelot (T0ha/camelot, GPL-2.0) |
| `CL` | CodeLead (emischorr/codelead, ELv2) |
| `SYM` | OpenAI Symphony (openai/symphony, Apache-2.0) |
| `HAR` | ZenHive Harness (ZenHive/harness, license unclear) |
| `ANK` | Ankole (AgentBull/ankole, Apache-2.0) |
| `TK` | TurboKanban (eadz/turbokanban, no license) |
| `JH` | jido_harness + Hex claude_agent_sdk / claude_code (Elixir building blocks) |
| `CDR` | Coder Agents / Tasks (+ AgentAPI), Coder OSS (AGPL-3.0) + Premium |
| `SWP` | Sweep (GitHub issue → PR bot) |
| `PLX` | Plandex (MIT) |
| `SWE` | SWE-agent / mini-SWE-agent (MIT) |
| `AID` | Aider (Apache-2.0) |

## Counts per category

| Category | Total | MVP | v1 | Later | Not planned |
|---|---|---|---|---|---|
| Triggers & entry points | 20 | 5 | 7 | 7 | 1 |
| Automations & scheduling | 10 | 0 | 4 | 5 | 1 |
| Session / run lifecycle | 21 | 10 | 4 | 7 | 0 |
| Agent backends & adapters | 15 | 8 | 2 | 4 | 1 |
| Models & providers | 12 | 4 | 4 | 2 | 2 |
| Sandbox & environments | 23 | 8 | 6 | 6 | 3 |
| Git & forge integration | 22 | 11 | 7 | 4 | 0 |
| Issue trackers & chat | 11 | 0 | 7 | 3 | 1 |
| Web UI | 22 | 9 | 7 | 5 | 1 |
| API & SDK | 18 | 8 | 6 | 4 | 0 |
| Tools & MCP | 12 | 2 | 7 | 2 | 1 |
| Human-in-the-loop & permissions | 10 | 4 | 4 | 2 | 0 |
| Teams, auth & governance | 13 | 4 | 7 | 2 | 0 |
| Secrets & security | 11 | 5 | 4 | 2 | 0 |
| Cost & usage | 7 | 3 | 3 | 1 | 0 |
| Observability | 8 | 3 | 3 | 1 | 1 |
| Memory & knowledge | 7 | 2 | 2 | 2 | 1 |
| Deployment & ops | 9 | 3 | 2 | 3 | 1 |
| Licensing & business | 8 | 2 | 0 | 2 | 4 |

## 1. Triggers & entry points

| Feature | Description | References | AgentYard priority |
|---|---|---|---|
| Start run from web UI | Compose prompt + repo + agent in a browser and launch an async run | `CUR` `CC` `OH` `CAM` `CL` `ANK` `TK` `CDR` | **MVP** |
| Start run via REST API | Programmatic create of a session/run | `CUR` `CMA` `OH` `ANK` `CDR` `SYM?` | **MVP** |
| Launch cloud run from local CLI | e.g. `claude --cloud "…"`; queue follow-ups from any terminal | `CC` `CUR?` | v1 — thin `agentyard` CLI over the REST API |
| Launch from desktop IDE | Pick 'Cloud' in the IDE agent dropdown | `CUR` `CC` | Not planned — no IDE of our own; API/CLI covers it |
| Mobile app / PWA | Start and steer runs from phone | `CUR` `CC` | Later — responsive web UI first |
| GitHub @mention in issue/PR comment | Comment `@bot …` → run → branch/PR | `CUR` `CC` `OH` `OHE` `SWP?` | **MVP** — OH via resolver GitHub Action; one-click app is OHE |
| GitHub label trigger | Adding a label (e.g. `agent`) starts a run | `OH` `CUR` `SWP?` | **MVP** — OH via resolver `fix-me` label |
| GitLab @mention / label on issues & MRs | Webhook on notes/labels → run → MR | `OHE` `CC` `CUR?` | **MVP** — OHE: gitlab.com in Cloud, self-managed Ent-only; CC via GitLab CI/CD (beta) |
| Bitbucket comment trigger | `@cursor` on Bitbucket PRs | `CUR` | Later |
| Slack mention trigger | `@bot` in a channel/thread starts a run | `CUR` `CC` `OHE` `ANK` | v1 — key differentiator vs OH OSS |
| Microsoft Teams trigger | Start runs from Teams | `CUR` `ANK` | Later |
| Linear trigger / sync | Issue created / status change starts a run | `CUR` `SYM` `OHE?` | Later — after Jira; via generic tracker adapter |
| Jira Cloud trigger | Ticket mention/label → run | `OHE` `SYM` | v1 — OSS in AgentYard (OHE-only in OpenHands) |
| Jira Data Center trigger | Self-managed Jira → run | `OHE` | v1 — self-managed parity is core positioning |
| Asana source | Poll Asana tasks as work items | `SYM` | Later |
| Sentry / PagerDuty triggers | Error or incident events start an investigation run | `CUR` | Later |
| Generic inbound webhook trigger | Private URL + key; POST to start a run from CI/monitoring | `CUR` `CC` | v1 |
| Tracker polling (no inbound webhooks) | Poll issue trackers on an interval instead of receiving webhooks | `SYM` `CAM` | v1 — useful for firewalled on-prem forges |
| No-repo / start-from-scratch run | Run without cloning a repository | `CUR` `CMA` `CDR` | Later |
| Image attachments in prompt | Paste screenshots/mockups into the task | `CUR` `CDR` `CC?` | v1 |

## 2. Automations & scheduling

| Feature | Description | References | AgentYard priority |
|---|---|---|---|
| Scheduled (cron) runs | Recurring runs on a cron expression | `CUR` `CMA` `CC` | v1 — Oban cron makes this cheap |
| SCM event triggers | PR opened/pushed/merged, push to branch, CI completed, review submitted … | `CUR` `CC` | v1 |
| Slack channel event triggers | New message / emoji reaction / channel created | `CUR` `OH?` | Later — OH has a Slack channel-monitor automation |
| Automation run-as identity | Run as creator vs dedicated service account (billing + identity) | `CUR` | v1 |
| Automation sharing & access | Private / members can view / members can edit | `CUR` | v1 |
| Natural-language automation builder | Describe a workflow; tool configures triggers/tools | `CUR` | Later |
| Automation templates marketplace | Prebuilt templates (fix CI, triage Sentry …) | `CUR` | Later |
| Managed PR review agent | Bugbot-style automatic review of PRs | `CUR` `CC` | Later — build as a template on top of SCM triggers |
| Security review agent | Scan PRs/codebase for vulnerabilities | `CUR` | Later |
| Auto-approve / route low-risk PRs | Agent requests reviewers or approves | `CUR` | Not planned — governance risk; out of scope |

## 3. Session / run lifecycle

| Feature | Description | References | AgentYard priority |
|---|---|---|---|
| Durable session + per-prompt runs | Session holds conversation/workspace; each prompt is a run | `CUR` `CMA` `CC` `OH` `CDR` | **MVP** — domain model core |
| Follow-ups on an idle session | Continue the same conversation and workspace | `CUR` `CMA` `CC` `OH` `CL` `TK` `CDR` `ANK` `CAM?` | **MVP** |
| Steer a running agent | Send messages mid-run (queued until next step if needed) | `CMA` `CC` `CDR` `OH?` | **MVP** — Claude Code via stream-json input; queue for adapters that can't |
| Cancel / interrupt | Stop the active run; terminal state | `CUR` `CMA` `CC` `OH` `CDR` `CAM?` `HAR?` | **MVP** |
| Take back a queued message | Retract a not-yet-read follow-up | `CC` | Later |
| Queueing + concurrency limits | Per-team/repo caps; one active run per session | `CUR` `SYM` `HAR` `CAM` | **MVP** — Oban queues |
| Parallel runs | Many independent runs at once | `CUR` `CC` `SYM` `HAR` `CDR` | **MVP** |
| Infrastructure retries | Retry provisioning/clone failures with backoff | `CAM?` `HAR?` `SYM?` | **MVP** — no automatic re-run of agent turns (cost) |
| Explicit run state machine | creating → running → finished/error/cancelled/expired | `CUR` `CMA` `HAR` `CL` | **MVP** |
| Wall-clock timeout / max turns | Hard stop by time or turns | `CC` `SYM?` | **MVP** |
| Per-issue / per-run workspace lifecycle | Create, reuse and clean up workspaces per task | `SYM` `CUR` `HAR` | **MVP** |
| Archive / unarchive / delete | Soft- and hard-delete sessions | `CUR` `CC` `CMA` | v1 — delete is MVP for data control |
| Idempotent create | Client-supplied id prevents duplicate runs | `CUR` | v1 |
| Hibernate + resume idle sessions | Snapshot/stop idle sandbox; restore on follow-up | `CUR` `CMA` `CC` | v1 — snapshot/hibernate instead of MVP's time-boxed volume |
| Plan mode | Explore and propose a plan before editing | `CUR` `CC` `CDR` `PLX` | v1 |
| Teleport session to local terminal | Pull branch + conversation into local CLI | `CC` | Later |
| Sub-agents / custom sub-agents | Delegate to child agents with own context | `CUR` `CC` `CDR` | Later — left to the CLI adapters |
| Multi-agent projects / agent teams | Coordinator spawns and tracks many sessions | `CC` `CDR` | Later |
| Implement → commit → review → settle pipeline | Staged lifecycle incl. automated review step | `HAR` `CL` | Later |
| Cross-model reviewer | Second agent from another model family reviews the diff | `HAR` | Later |
| Multi-repo runs | One task spans several repositories | `CUR` `SYM?` | Later |

## 4. Agent backends & adapters

| Feature | Description | References | AgentYard priority |
|---|---|---|---|
| Claude Code adapter | `claude -p --output-format stream-json` | `CC` `OH` `CAM` `CL` `HAR` `JH` `TK?` | **MVP** — Hex claude_agent_sdk / claude_code or jido_harness |
| Cursor CLI adapter | `agent -p --output-format stream-json` | `CUR` `HAR` `JH` `TK?` | **MVP** — not first-class in OpenHands |
| OpenRouter / API-only agent path | Built-in thin loop or Aider/opencode pointed at OpenRouter | `OH` `CDR` `AID` `PLX` `ANK` | **MVP** — pick one path; decision open |
| Codex CLI adapter | `codex exec` / app-server | `SYM` `CAM` `CL` `HAR` `JH` `OH` `TK?` | v1 |
| Gemini CLI adapter | `gemini -p` | `OH` `JH` `TK?` | Later |
| Aider adapter | `aider --message` | `AID` `TK?` | Later — may be the MVP OpenRouter path instead |
| OpenCode adapter | opencode headless | `JH` | Later |
| Long-tail CLIs (Amp, Grok, Kimi, Pi …) | Additional agent CLIs | `JH` `HAR` | Later — cheap if built on jido_harness |
| Built-in native agent loop | Own tool loop (bash/read/edit) instead of wrapping a CLI | `OH` `CMA` `CDR` `SWE` `PLX` `AID` `ANK` | **MVP** — conditional: only if chosen as the OpenRouter path (vs Aider) |
| ACP (Agent Client Protocol) support | Talk to agents over ACP | `OH` `CL` `JH` | **MVP** — comes with jido_harness |
| Pluggable adapter behaviour | Elixir behaviour: prepare/start/follow_up/cancel/normalize | `HAR` `JH` `CAM?` | **MVP** |
| Normalized event stream | Common status/assistant/tool_call/usage/result events across CLIs | `CUR` `CMA` `JH` `HAR` | **MVP** |
| Custom agent command template | Admin-defined CLI invocation for unsupported agents | `TK` `OH` | v1 — OH: custom ACP command |
| HTTP wrapper around CLI agents | Generic HTTP control API for terminal agents (AgentAPI) | `CDR` | Not planned — our adapters cover it |
| CLI version pinning & detection | Pin agent CLI versions in images; detect binary name | — | **MVP** — supply-chain hygiene |

## 5. Models & providers

| Feature | Description | References | AgentYard priority |
|---|---|---|---|
| BYO Anthropic key | Team supplies its own Anthropic key | `CC` `CMA` `OH` `CL` `CDR` `AID` `PLX` | **MVP** |
| BYO Cursor API key | User/service-account Cursor key for Cursor CLI | `CUR` | **MVP** |
| OpenRouter provider | Route to any OpenRouter model | `OH` `CDR` `ANK` `AID` `PLX` | **MVP** |
| Custom OpenAI-compatible base URL | Internal gateways / EU proxies / self-hosted models | `OH` `CDR` `AID` `SWE` | **MVP** — same code path as OpenRouter |
| AWS Bedrock / Google Vertex | Cloud-provider hosted Claude/Gemini, incl. regional endpoints | `CC` `CDR` `OH` | v1 — EU-region model hosting |
| Local models (Ollama etc.) | Run against on-prem models | `CL` `OH` `AID` | v1 — via OpenAI-compatible endpoint |
| Model catalog + per-model params | List models; set reasoning effort / context window | `CUR` | v1 |
| Default model resolution | User → team → system default | `CUR` `CDR` | v1 |
| Model routing / fallback gateway | Central AI gateway with routing | `ANK` `OH?` | Later |
| Role-based model packs | Different models for planner/coder/editor | `PLX` `AID` | Later |
| Vendor-resold models at cost | Use the vendor's model billing | `OHE` `CUR` `CMA` | Not planned — BYOK only |
| Prompt caching / context compaction | Harness-level token optimizations | `CMA` `CC` `CDR` `OH` | Not planned — handled inside the CLIs |

## 6. Sandbox & environments

| Feature | Description | References | AgentYard priority |
|---|---|---|---|
| Container per run | Isolated Docker container for each run | `OH` `SWE` `CC` `CAM?` `CL?` | **MVP** — CL: devcontainer is paid tier |
| VM / microVM per run | Full VM isolation | `CUR` `CMA` `CC` | Later — Firecracker milestone |
| Lightweight OS sandbox (bubblewrap) | Namespaced worker processes | `ANK` | Later |
| Git worktree isolation (no container) | Parallel agents in separate worktrees on one host | `CL` `HAR` | Not planned — only as a dev mode; not isolation |
| Dockerfile-based environment | Env defined by a Dockerfile in the repo | `CUR` `OH` | **MVP** — `.agentyard/` config, Cursor-style |
| Build-time install vs run-time start commands | Cached install; per-run start commands | `CUR` `CC` | **MVP** |
| Container hardening | Non-root, dropped caps, read-only rootfs where feasible | — | **MVP** |
| CPU / RAM limits | Per-profile resource limits | `CDR?` | **MVP** |
| Network egress allowlist | Default deny + allowlisted domains | `CUR` `CC` `CDR` `CMA` | **MVP** |
| Persistent workspace across follow-ups | Keep volume while session is idle | `CUR` `CMA` `CC` | **MVP** — volume kept for a time-boxed idle window; then rebuild from branch tip |
| Prebuilt base images with common tools | Language toolchains + agent CLIs preinstalled | `CC` `CMA` `OH` | **MVP** |
| Environment snapshots | Save a prepared environment and reuse it | `CUR` `CMA?` | v1 |
| Background builds + version history | Pre-build environments; show which build a run used | `CUR` | v1 |
| Devcontainer support | Use devcontainer.json as env spec | `CL` `CDR?` | v1 |
| Remote / self-hosted runners | Workers on other machines, outbound connection to control plane | `CUR` `CMA` `CC` `OHE` | v1 — CUR team pools are Enterprise-only |
| Kubernetes runner | Pod/Job per run | `CUR` `OHE` `CDR` | v1 |
| Pool routing by label | Route runs to gpu/mac/etc. pools | `CUR` | Later |
| Warm pools + autoscaling controller | Pre-warmed idle workers; scale on queue depth | `CUR` | Later |
| Agent-led environment setup | Agent figures out and saves the setup | `CUR` | Later |
| Private network connectivity | Tailscale or similar from the sandbox | `CUR` | Later — self-hosting is usually already inside the network |
| Git/API credentials kept outside sandbox | Proxy injects scoped credentials; agent never sees tokens | `CC` | v1 — strong security win |
| No LLM keys in sandbox | Agent loop runs in control plane; workspace needs no AI egress | `CDR` | Not planned — incompatible with wrapping CLIs; revisit for native loop |
| Upload local repo bundle (no forge) | Send a local repo to a cloud session | `CC` | Not planned |

## 7. Git & forge integration

| Feature | Description | References | AgentYard priority |
|---|---|---|---|
| GitHub.com via GitHub App | Installation tokens, webhooks, clone/push/PR | `CUR` `CC` `OH` `OHE` `CAM` `SWP` | **MVP** — OH uses a token; the one-click GitHub App is OHE |
| GitHub Enterprise Server | Self-hosted GitHub | `CUR` `CC` `OHE?` | v1 |
| GitLab.com | OAuth/app + webhooks, MRs | `CUR` `OHE` `CC` `SYM` `OH?` | **MVP** — SYM as tracker only; OH OSS partial (one-click is Cloud) |
| GitLab self-managed | Self-hosted GitLab parity | `CUR` `OHE` `CC` | **MVP** — Enterprise-only in OpenHands |
| Bitbucket Cloud | Bitbucket repos + PRs | `CUR` | Later |
| Azure DevOps | Azure Repos | `CUR` | Later |
| Generic git remote | Any git URL with credentials, no forge API | `CL` `HAR` `AID` `PLX` | v1 |
| Clone at ref + agent branch | Start from branch/SHA; push to `agent/…` branch | `CUR` `CC` `OH` `CAM` `CL` `SYM` | **MVP** |
| Auto-open PR/MR | Open PR/MR on completion (configurable) | `CUR` `CC` `OH` `CAM` `CL` `SWP` | **MVP** — OH via resolver (draft PR) |
| Work on existing PR branch | Push to the PR head branch instead of a new branch | `CUR` `CC` | **MVP** — needed for @mention-on-PR |
| Progress + result comments on issue/PR | Bot posts status and final link | `CC` `OHE` `SWP` `CUR?` `OH?` | **MVP** |
| Mention permission check | Only users with write access can trigger | `CC` `CUR?` | **MVP** |
| Fork-PR safety | Refuse runs on fork PR code with repo permissions | `CUR` | **MVP** |
| Least-privilege, short-lived forge tokens | Installation/project tokens, downgraded scopes | `CC` `OHE` `CUR?` | **MVP** |
| Commit/comment identity policy | Bot identity vs acting user, labeled as agent | `CUR` `CC` `CDR` | **MVP** |
| PR status tracking | Track open/merged/closed per run | `CAM` `CL?` | v1 |
| CI feedback loop (auto-fix failing checks) | Watch PR checks and push fixes | `CC` `CUR` | v1 |
| Handle review comments | Respond to inline review comments with fixes | `CC` `CUR` `SWP?` | v1 |
| Request reviewers | Assign reviewers on created PRs | `CUR` | v1 |
| Repo access verification for viewers | Viewer must have forge access to see a run | `CUR` `CC` | v1 |
| Local merge without forge PR | Merge worktree branch locally | `CL` | Later |
| Stacked branches per session | Multiple pushed branches/PRs per session | `CUR` | Later |

## 8. Issue trackers & chat

| Feature | Description | References | AgentYard priority |
|---|---|---|---|
| Slack app: mention → run | Start runs from Slack | `CUR` `CC` `OHE` `ANK` | v1 |
| Slack thread follow-ups | Reply in thread to continue the session | `OHE` `CUR?` | v1 |
| Slack notifications | Post PR link / status to channel | `CUR` `OHE?` | v1 |
| Jira Cloud integration | Ticket → run → PR, status back to ticket | `OHE` `SYM` | v1 |
| Jira Data Center integration | Same for self-managed Jira | `OHE` | v1 |
| GitHub Issues as work queue | Sync issues into the task list/board | `CAM` `SYM` | v1 |
| Tracker status transitions | Move ticket when run starts/finishes | `SYM` `CL?` | v1 — with Jira |
| Linear integration | Linear issues as triggers/sources | `CUR` `SYM` `OHE?` | Later |
| Asana integration | Asana as work source | `SYM` | Later |
| Microsoft Teams integration | Teams bot | `CUR` `ANK` | Later |
| Other chat (Feishu etc.) | Non-Western chat platforms | `ANK` | Not planned |

## 9. Web UI

| Feature | Description | References | AgentYard priority |
|---|---|---|---|
| Team-wide runs dashboard | List/filter runs by status, repo, agent, trigger, cost | `CUR` `CC` `OH` `CAM` `CL` `SYM` `HAR` `ANK` | **MVP** |
| New run composer | Repo/branch, profile, prompt, issue, env | `CUR` `CC` `OH` | **MVP** |
| Live event timeline | Streaming assistant text + tool calls | `CUR` `CC` `OH` `CAM` `CL` `HAR` `TK` | **MVP** — LiveView streams |
| Terminal output view | Command output per tool call | `OH` `TK` `CUR?` | **MVP** |
| Diff viewer | Per-file diff with +/- summary | `CC` `CUR` `OH` `CL` | **MVP** |
| Usage & cost panel | Tokens, USD, budget per run | `CL` `CUR` `TK` | **MVP** |
| Search & filter runs | Full-text and facet filters | `CUR?` `CC` | **MVP** |
| Share run with team | Team-visible run URL | `CUR` `CC` | **MVP** — default visible to team under RBAC |
| Setup/build progress view | Live checklist of clone/build/setup steps | `CC` `CUR` | **MVP** |
| Inline diff comments sent to agent | Comment on lines → next follow-up | `CC` | v1 |
| Artifacts (screenshots, videos, logs) | Browse files produced by the run | `CUR` | v1 — logs are MVP |
| HITL approval / review UI | Approve plans, tool calls, or move to review | `CL` `CC` `CDR` `CAM?` | v1 |
| Team follow-ups toggle | Let teammates continue someone else's run | `CUR` | v1 |
| Per-run environment inspection | Which image/build/env a run used | `CUR` | v1 |
| Ops dashboard (jobs/queues) | Oban Web-style queue view for admins | `HAR` | v1 |
| Mobile-responsive UI | Usable on phones | `CUR` `CC` | v1 |
| Kanban board view | Tasks as cards moving through columns | `CAM` `CL` `TK` | Later — runs list first |
| Compare diff against any branch | Choose diff base | `CC` | Later |
| Interactive web terminal | Human shell into the sandbox | `TK` `CDR` `OH?` | Later |
| Embedded browser view | See the agent's browser | `OH` | Later |
| Remote desktop control | Take over the agent's desktop, hand back | `CUR` | Later |
| In-browser IDE | VS Code in the browser | `OH` `CDR` | Not planned — non-goal |

## 10. API & SDK

| Feature | Description | References | AgentYard priority |
|---|---|---|---|
| REST: create / follow-up / cancel / get | Core run API | `CUR` `CMA` `OH` `ANK` `CDR` | **MVP** |
| SSE event stream | Stream run events | `CUR` `CMA` | **MVP** |
| Stream resume (Last-Event-ID) | Reconnect without losing events | `CUR` | **MVP** — cheap with persisted events |
| Persisted event history | Fetch full event log after the fact | `CMA` `CUR` `OH` | **MVP** |
| Usage endpoint | Token/cost per run and session | `CUR` | **MVP** |
| OpenAPI spec | Machine-readable API description | `CUR` | **MVP** — OpenApiSpex |
| Personal API tokens | User-scoped API keys | `CUR` `CMA` | **MVP** |
| List repositories endpoint | Repos available to the caller | `CUR` | **MVP** |
| Service-account API keys | Non-human keys billed to team | `CUR` | v1 |
| Outbound webhooks | Notify external systems on run events | `CUR` | v1 — CUR: v0 only, v1 'coming soon' |
| Artifacts API | List + presigned download | `CUR` | v1 |
| Models endpoint | List models/params | `CUR` | v1 |
| CLI client | Command-line client for the API | `CC` `CUR` | v1 |
| MCP server exposing the control plane | Let other agents start/inspect runs via MCP | `HAR` `CUR` | v1 — CUR: built-in diagnostics MCP |
| WebSocket API | Bidirectional socket API | `OH?` | Later — SSE + REST suffices |
| Official client SDKs (TS/Python) | Typed SDKs | `CUR` `CMA` `CC` `OH` | Later |
| Terraform provider | Manage automations as code | `CUR` | Later |
| Worker / pool management API | Pending queue, claim, release, autoscale | `CUR` | Later |

## 11. Tools & MCP

| Feature | Description | References | AgentYard priority |
|---|---|---|---|
| MCP client passthrough (stdio/HTTP) | Configure MCP servers for the agent | `CUR` `CMA` `CC` `OH` `CDR` | **MVP** — written into CLI config |
| Built-in bash/file tools | Shell, read, edit, grep | `CMA` `CC` `CDR` `OH` `SWE` | **MVP** — provided by the adapters |
| Team-level MCP registry | Admin-managed MCP servers | `CUR` `OH?` | v1 |
| Inline per-run MCP definitions | Pass MCP servers in the API request | `CUR` | v1 |
| MCP OAuth | OAuth for remote MCP servers | `CUR` | v1 |
| Hooks (pre/post tool, lifecycle) | Formatters, policy checks around tool use | `CUR` `CC` | v1 |
| Skills / custom tools | Packaged instructions + scripts | `CMA` `CC` `OH` `CDR` `CUR` | v1 |
| Web search / fetch with domain policy | Allow/block lists for web tools | `CMA` `CC` `CDR` | v1 |
| Built-in automation tools | Send to Slack, comment on PR, request reviewers | `CUR` | v1 |
| Browser / computer use | Operate a browser or desktop, record demos | `CUR` `CDR` `OH` | Later |
| MCP tunnels to private servers | Reach private MCP servers from the sandbox | `CMA` | Later — research preview in CMA |
| Elixir dev MCP (Tidewave) | Framework-specific MCP | `HAR` | Not planned |

## 12. Human-in-the-loop & permissions

| Feature | Description | References | AgentYard priority |
|---|---|---|---|
| Permission modes | ask / accept-edits / plan / bypass per profile | `CC` `CUR` `OH` `CAM` | **MVP** — safe default; explicit 'yolo' profile |
| Tool allow/deny lists | Restrict tools per profile | `CC` `CAM` `CDR` | **MVP** |
| Budget hard stop | Pause/stop when budget reached | `CL` `CC` | **MVP** |
| Who-can-trigger policy | Forge role / team role gates on triggers | `CC` `CUR` `OHE?` | **MVP** |
| Review stage before PR/merge | HITL review column | `CL` `HAR` | v1 |
| Clarifying questions | Agent asks and waits for answer | `CC` `CDR` `CMA?` | v1 |
| Approve plan before implementation | Plan → approve → execute | `CDR` `CUR` `CC` | v1 |
| Server-enforced admin policy | Models/prompts/tools not overridable by users | `CDR` `CUR` | v1 |
| Diff review before apply | Changes staged in a sandbox, applied on approval | `PLX` | Later — PR review covers this |
| Risk-based confirmation (security analyzer) | LLM rates actions; confirm risky ones | `OH` | Later |

## 13. Teams, auth & governance

| Feature | Description | References | AgentYard priority |
|---|---|---|---|
| Multi-user accounts | Many users per instance | `CUR` `CC` `OHE` `ANK` `CDR` `CL?` `CAM?` | **MVP** — Enterprise-gated in OpenHands |
| Roles / RBAC | owner/admin/member/viewer | `OHE` `ANK` `CUR` `CDR` | **MVP** — OSS in AgentYard |
| Email / magic-link auth | Built-in login without IdP | `CAM` | **MVP** |
| Basic audit log | Who started/changed what | `CDR` `CUR?` `OHE?` | **MVP** — export in v1 |
| SSO via OIDC | Login via company IdP | `OHE` `CUR` `CDR` | v1 — OSS, not paywalled |
| SAML | SAML IdPs | `OHE` `CUR?` `CDR` | v1 |
| Repo-level ACL mirrored from forge | Visibility follows forge permissions | `CUR` `CC` | v1 |
| Organizations / multiple teams | Several teams per instance | `CUR` `CDR` `OHE` | v1 |
| Service accounts | Non-human identities | `CUR` | v1 |
| Admin policy toggles | e.g. require self-hosted runners, disable features | `CUR` `CC` | v1 |
| Audit log export | SIEM export / API | `CDR?` `OHE?` | v1 |
| SCIM provisioning | Automatic user lifecycle | `CDR?` `CUR?` | Later |
| Multi-tenant SaaS isolation | Hard tenant isolation for hosted tier | `OHE` `CUR` | Later — hosted tier only |

## 14. Secrets & security

| Feature | Description | References | AgentYard priority |
|---|---|---|---|
| Encrypted secrets at rest | Cloak/AES-GCM with instance key | `OH` `CL` `CUR` | **MVP** — OH: OH_SECRET_KEY; OHE adds JWE DB encryption |
| Scoped secrets (team/repo/profile) | Injected only where scoped | `CUR` `OH?` | **MVP** |
| Secret masking in logs/events | Replace known values in output | `OH` | **MVP** |
| Write-only secret UI | Values never re-displayed | `OH` | **MVP** |
| Session-scoped env vars via API | Ephemeral secrets deleted with the session | `CUR` | v1 |
| External vault integration | HashiCorp Vault / AWS Secrets Manager | `OH?` | v1 — OH only via custom SecretSource code |
| Master key rotation | Re-encrypt with a new key | — | v1 |
| Workload identity (OIDC) to clouds | No static cloud keys | `CC` `CUR` | Later |
| Data retention & deletion controls | Delete sessions/files; retention policy | `CMA` `CC` | v1 |
| Untrusted-input guardrails | Caution on memories/fork PRs/public issues | `CUR` `CC` | **MVP** |
| Compliance trust center | SOC2 etc. attestations | `OHE` `CUR?` `CC?` | Later — business, not product |

## 15. Cost & usage

| Feature | Description | References | AgentYard priority |
|---|---|---|---|
| Token tracking per run | Input/output/cache tokens | `CUR` `CL` `CC` `OH` `TK` | **MVP** |
| USD cost per run | From CLI result events / price table | `CC` `CL` `OH?` | **MVP** |
| Per-run budget cap | e.g. `--max-budget-usd` + control-plane cap | `CC` `CL` | **MVP** |
| Team spend limits / quotas | Monthly caps per team | `CUR` `ANK` | v1 |
| Attribution by team/user/repo | Who spent what | `CUR` `ANK` | v1 |
| Usage dashboards | Trends over time | `CUR` `CDR?` | v1 |
| Pre-run cost estimate | Estimate from similar runs | — | Later — shown in prototype |

## 16. Observability

| Feature | Description | References | AgentYard priority |
|---|---|---|---|
| Persisted per-run event log | Durable, replayable events | `CUR` `CMA` `OH` `CAM` `CL` | **MVP** |
| Setup / build logs | Clone, build and install output | `CUR` `CC` | **MVP** |
| Structured app logs with run id | Correlated logs | — | **MVP** |
| Transcript export | Download full conversation | `CUR` `CC` | v1 |
| OpenTelemetry traces/metrics | OTel export | `CC` `OH?` | v1 |
| Prometheus metrics | Queue depth, run durations, failures | — | v1 |
| Diagnostics MCP | Agents inspect runs via MCP | `CUR` | Later |
| Trajectory inspector | Research-style step browser | `SWE` | Not planned |

## 17. Memory & knowledge

| Feature | Description | References | AgentYard priority |
|---|---|---|---|
| Repo rules files | AGENTS.md / CLAUDE.md / .cursor/rules honored | `CC` `CUR` `OH` `AID` `SYM` | **MVP** — CLIs read them natively |
| Profile instructions / system prompt | Per-profile instructions | `CMA` `CAM` `CL?` `CUR?` | **MVP** |
| Prompt templates / workflow Markdown | Reusable task templates | `CAM` `SYM` | v1 |
| Skills | Reusable skill packages | `CMA` `CC` `OH` `CDR` `CUR` | v1 |
| Keyword-triggered microagents | Knowledge injected by keyword | `OH` | Later |
| Persistent memories across runs | Agent-maintained notes between runs | `CUR` `CMA?` `ANK?` | Later — prompt-injection risk |
| Repo map / large-codebase indexing | Codebase maps for context | `AID` `PLX` `OHE` | Not planned — CLI's job |

## 18. Deployment & ops

| Feature | Description | References | AgentYard priority |
|---|---|---|---|
| Docker Compose install | One-command self-host | `CAM` `CL` `OH` `ANK` `PLX` | **MVP** |
| EU-hostable self-host | Runs anywhere, incl. EU clouds; no US SaaS dependency | `OH` `OHE` `CDR` `CMA?` `CC?` | **MVP** — CMA/CC: self-hosted sandbox only |
| DB migrations on upgrade | Safe, automatic migrations | — | **MVP** |
| Helm chart / Kubernetes | K8s deployment | `OHE` `CUR` `CDR` | v1 |
| Backups & restore guide | Postgres + object storage | — | v1 |
| Single-binary releases | Burrito-style binaries | `SYM` `TK` | Later |
| HA / clustered control plane | BEAM clustering, multiple nodes | `OHE?` | Later |
| Air-gapped install | No internet at install/run | `CDR?` `OHE?` | Later |
| Replicated-style enterprise installer | Licensed installer tooling | `OHE` | Not planned |

## 19. Licensing & business

| Feature | Description | References | AgentYard priority |
|---|---|---|---|
| OSI open-source core | Permissive/copyleft OSI license | `OH` `SYM` `ANK` `JH` `AID` `SWE` `PLX` `CDR` | **MVP** — Apache-2.0 |
| Team features open source | Multi-user/RBAC/SSO not paywalled | `ANK` `CDR?` | **MVP** — core positioning |
| Managed hosted offering | Vendor-run SaaS | `CUR` `CMA` `CC` `OHE` | Later — optional EU hosted tier |
| Paid support / SLA | Commercial support | `OHE` `CDR` | Later |
| Source-available enterprise tier | PolyForm/ELv2/proprietary add-ons | `OHE` `CL` `CDR` | Not planned — commercial add-ons only for ops extras |
| Free individual SaaS tier | Free hosted single user | `OHE` | Not planned |
| Usage-based billing at API prices | Vendor bills model usage | `CUR` `CMA` | Not planned — BYOK |
| Copyleft license | GPL/AGPL | `CAM` `CDR` | Not planned |

## MVP feature list (grouped)

- **Triggers & entry points:** Start run from web UI; Start run via REST API; GitHub @mention in issue/PR comment; GitHub label trigger; GitLab @mention / label on issues & MRs
- **Session / run lifecycle:** Durable session + per-prompt runs; Follow-ups on an idle session; Steer a running agent; Cancel / interrupt; Queueing + concurrency limits; Parallel runs; Infrastructure retries; Explicit run state machine; Wall-clock timeout / max turns; Per-issue / per-run workspace lifecycle
- **Agent backends & adapters:** Claude Code adapter; Cursor CLI adapter; OpenRouter / API-only agent path; Built-in native agent loop; ACP (Agent Client Protocol) support; Pluggable adapter behaviour; Normalized event stream; CLI version pinning & detection
- **Models & providers:** BYO Anthropic key; BYO Cursor API key; OpenRouter provider; Custom OpenAI-compatible base URL
- **Sandbox & environments:** Container per run; Dockerfile-based environment; Build-time install vs run-time start commands; Container hardening; CPU / RAM limits; Network egress allowlist; Persistent workspace across follow-ups; Prebuilt base images with common tools
- **Git & forge integration:** GitHub.com via GitHub App; GitLab.com; GitLab self-managed; Clone at ref + agent branch; Auto-open PR/MR; Work on existing PR branch; Progress + result comments on issue/PR; Mention permission check; Fork-PR safety; Least-privilege, short-lived forge tokens; Commit/comment identity policy
- **Web UI:** Team-wide runs dashboard; New run composer; Live event timeline; Terminal output view; Diff viewer; Usage & cost panel; Search & filter runs; Share run with team; Setup/build progress view
- **API & SDK:** REST: create / follow-up / cancel / get; SSE event stream; Stream resume (Last-Event-ID); Persisted event history; Usage endpoint; OpenAPI spec; Personal API tokens; List repositories endpoint
- **Tools & MCP:** MCP client passthrough (stdio/HTTP); Built-in bash/file tools
- **Human-in-the-loop & permissions:** Permission modes; Tool allow/deny lists; Budget hard stop; Who-can-trigger policy
- **Teams, auth & governance:** Multi-user accounts; Roles / RBAC; Email / magic-link auth; Basic audit log
- **Secrets & security:** Encrypted secrets at rest; Scoped secrets (team/repo/profile); Secret masking in logs/events; Write-only secret UI; Untrusted-input guardrails
- **Cost & usage:** Token tracking per run; USD cost per run; Per-run budget cap
- **Observability:** Persisted per-run event log; Setup / build logs; Structured app logs with run id
- **Memory & knowledge:** Repo rules files; Profile instructions / system prompt
- **Deployment & ops:** Docker Compose install; EU-hostable self-host; DB migrations on upgrade
- **Licensing & business:** OSI open-source core; Team features open source

## Differentiators

These are features AgentYard plans for MVP/v1 in its **open-source** core that the OSS alternatives either lack or keep behind paid/source-available tiers:

1. **Multi-user + RBAC in the OSS core (MVP).** OpenHands OSS has no auth/RBAC/multi-user (Cloud/Enterprise only); Camelot lists team collaboration as roadmap; CodeLead stores roles but doesn't enforce them; Symphony, Harness and TurboKanban are single-operator.
1. **SSO (OIDC/SAML) and audit log without a paywall (v1; basic audit log in MVP).** OpenHands: Enterprise (SAML/SSO, Keycloak RBAC). Cursor: team/Enterprise plans. Coder: audit log is a Premium feature (unverified whether Coder Agents themselves are gated).
1. **Self-managed GitLab as a first-class forge (MVP).** OpenHands: GitLab self-managed is Enterprise-only. None of the Elixir projects support GitLab MRs (Symphony only uses GitLab as a tracker). Claude Code on the web can't push to GitLab; GitLab CI/CD is a beta maintained by GitLab.
1. **Slack + Jira Cloud + Jira Data Center in OSS (v1).** OpenHands: one-click Slack/Jira in Cloud; Jira Data Center is Enterprise. None of the Elixir apps have Slack/Jira bots (Symphony polls Jira Cloud only).
1. **Claude Code + Cursor CLI + OpenRouter under one team control plane (MVP).** OpenHands has no first-class Cursor CLI (ACP presets: Claude Code, Codex, Gemini). Cursor and Anthropic run only their own agents. ZenHive Harness has Cursor but no forge/team product. Camelot and CodeLead: Claude Code + Codex only.
1. **Permissive Apache-2.0 license covering team features.** vs PolyForm Free Trial (OpenHands Enterprise), ELv2 (CodeLead), GPL-2.0 (Camelot), AGPL + Premium (Coder), no license (TurboKanban), unclear (Harness).
1. **Fully self-hosted control plane, EU-hostable, no vendor SaaS in the loop (MVP).** Cursor Self-Hosted Machines still has Cursor run orchestration + inference, and Team Pools need Enterprise. Claude Managed Agents / Claude Code self-hosted environments still use Anthropic's control plane. OpenHands Cloud states no EU residency; self-hosting it for teams means Enterprise.
1. **Self-hosted runner pools without an Enterprise plan (v1).** Cursor Team Pools and the K8s worker path require Cursor Enterprise.
1. **Cross-vendor cost tracking, budgets and team attribution (MVP/v1).** Cursor and Anthropic track only their own usage; CodeLead has budgets but no enforced multi-user; OpenHands cost tracking is partial in OSS.
1. **Credentials kept outside the sandbox, self-hosted (v1).** Claude Code on the web does this only in Anthropic-hosted environments; self-hosted environments bring their own git credentials.
1. **Forge-native triggers in OSS: @mention/label → run → PR/MR with fork-PR safety and write-access checks (MVP).** OpenHands OSS relies on the resolver Action (one-click apps are Cloud/Ent). Camelot polls GitHub; webhooks are still on its roadmap.

**Auto-derived check:** these catalog features are confirmed only in OpenHands Cloud/Enterprise (no `OH` or `OH?`; `OHE?` excluded), and AgentYard plans them for MVP/v1:

- GitLab @mention / label on issues & MRs (Triggers & entry points, MVP)
- Slack mention trigger (Triggers & entry points, v1)
- Jira Cloud trigger (Triggers & entry points, v1)
- Jira Data Center trigger (Triggers & entry points, v1)
- Remote / self-hosted runners (Sandbox & environments, v1)
- Kubernetes runner (Sandbox & environments, v1)
- GitLab self-managed (Git & forge integration, MVP)
- Least-privilege, short-lived forge tokens (Git & forge integration, MVP)
- Slack app: mention → run (Issue trackers & chat, v1)
- Slack thread follow-ups (Issue trackers & chat, v1)
- Jira Cloud integration (Issue trackers & chat, v1)
- Jira Data Center integration (Issue trackers & chat, v1)
- Multi-user accounts (Teams, auth & governance, MVP)
- Roles / RBAC (Teams, auth & governance, MVP)
- SSO via OIDC (Teams, auth & governance, v1)
- SAML (Teams, auth & governance, v1)
- Organizations / multiple teams (Teams, auth & governance, v1)
- Helm chart / Kubernetes (Deployment & ops, v1)

## Notes & uncertainties

- Cursor: webhooks are documented for API v0; v1 says "coming soon". Team Pools and service-account keys are Enterprise-only (Cursor docs + forum staff, 2026). `@cursor` comment triggers are documented for GitHub and Bitbucket; GitLab is covered via Automations triggers (marked `CUR?` where it matters).
- Claude Code: GitLab CI/CD integration is beta and maintained by GitLab. Cloud sessions need GitHub to push; GHES is supported on Team/Enterprise plans.
- Claude Managed Agents: "dreaming" (memory) and MCP tunnels are limited research previews; scheduled deployments give cron runs.
- Coder: the "Tasks" docs URL now describes **Coder Agents** (its own Go agent loop, any LLM incl. OpenRouter, sub-agents, plan mode, message queuing). Which features are Premium vs OSS wasn't verified (marked `CDR?`).
- Elixir projects: presence is based on the README/code review in `appendix/elixir-prototypes-review.md`. Items that review marked unverified keep `?` here.
- Sweep and SWE-agent entries are limited to well-known behaviour (issue → PR); finer details are marked `?`.

*Generated from `tools/features_data.py` via `tools/build_features.py`; edit the data file and re-run to update both FEATURES.md and FEATURES.csv.*
