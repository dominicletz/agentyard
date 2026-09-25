# Appendix: Elixir prototypes review

**Research date:** 2026-09-24 (CEST). Inspected via GitHub API (`get_repository`, `get_file_contents`, `list_commits`, `get_git_tree`, search) and official READMEs—**no clones**. Earlier landscape names corrected where wrong.

### Naming corrections

| Name in earlier draft | Reality |
|----------------------|---------|
| AgentBull/ankole | **[AgentBull/ankole](https://github.com/AgentBull/ankole)** (org `AgentBull`) |
| CodeLead | Exists as **[emischorr/codelead](https://github.com/emischorr/codelead)** |
| Camelot | **[T0ha/camelot](https://github.com/T0ha/camelot)** |
| TurboKanban | **[eadz/turbokanban](https://github.com/eadz/turbokanban)** |
| Harness | **[ZenHive/harness](https://github.com/ZenHive/harness)** |
| *(missed earlier)* | **[openai/symphony](https://github.com/openai/symphony)** — major Elixir Codex orchestrator |
| *(missed earlier)* | **[agentjido/jido_harness](https://github.com/agentjido/jido_harness)** — CLI adapter library |

---

### Per-project findings (verified)

#### 1. OpenAI Symphony — `openai/symphony`

| Field | Value |
|-------|--------|
| URL | https://github.com/openai/symphony |
| License | **Apache-2.0** |
| Stars | **~27.4k** (2026-09-24) |
| Language | Elixir (reference impl under `elixir/`) |
| Created / last push | 2026-02-26 / 2026-09-15 |
| Commits (approx.) | ~47 pages × 1 → **~47+** on default listing pagination; active |
| Issues | **Disabled** on GitHub |
| Status | Explicit **engineering preview / prototype**; recommend implementing your own from `SPEC.md` |

**Implements (from `elixir/README.md` + root README):** Polls trackers (**Linear, GitHub Issues, Jira Cloud, Asana, GitLab**); creates per-issue workspaces; launches **Codex App Server** (`codex app-server`); workflow Markdown prompts; optional Phoenix LiveView dashboard + JSON API; concurrency limits; Burrito binaries. **Not** a multi-CLI adapter plane: agent backend is **Codex-centric**. Sandboxing is Codex thread/turn sandbox policy, not Docker-per-run from Symphony itself. No Claude Code / Cursor CLI / OpenRouter as first-class backends. No team RBAC product surface. Secrets via host env (`$LINEAR_API_KEY`, etc.).

**Completeness vs concept:** **Medium on orchestration patterns; low on multi-agent BYO-CLI + team Git product.**
**Fork base?** Study **SPEC.md** and tracker/workspace patterns. Forking the Elixir tree as *the* product is weak: OpenAI-owned, preview warning, Codex-locked, issues off.

Sources: [repo](https://github.com/openai/symphony), [elixir/README](https://github.com/openai/symphony/blob/main/elixir/README.md), [SPEC](https://github.com/openai/symphony/blob/main/SPEC.md).

#### 2. Camelot — `T0ha/camelot`

| Field | Value |
|-------|--------|
| URL | https://github.com/T0ha/camelot |
| License | **GPL-2.0** |
| Stars | **10** |
| Created / last push | 2026-03-16 / 2026-09-24 (active) |
| Commits (approx.) | API `rel=last` page **397** → ~397 commits |
| Packaging | **Dockerfile + docker-compose.yml** present |

**Implements:** Phoenix LiveView + **Ash** kanban; **Oban**; OTP `TaskRunner`; agents wrap **Claude Code and Codex CLIs**; GitHub issue sync + PR tracking (polling; webhooks still roadmap); live session streaming; prompt templates; tool permission controls; magic-link auth (AshAuthentication). Roadmap still open: webhook GitHub, more agents, **team/multi-user collaboration**, Camelot Cloud. GitLab **not** claimed. Cursor CLI **not** first-class (only Claude/Codex in README). Secrets: not Cloak-documented in README (unverified beyond env/GitHub App secrets).

**Completeness vs concept:** **Highest among small community Elixir apps (~55–65%)** — closest product shape (board → CLI agent → PR).
**Fork base?** Architecturally reasonable (Ash/Oban/LiveView). **GPL-2.0** conflicts with an Apache-2.0 + commercial dual-license strategy unless Dominic accepts GPL. Incomplete multi-user/GitLab/Cursor.

Sources: [README](https://github.com/T0ha/camelot/blob/main/README.md), [LICENSE](https://github.com/T0ha/camelot/blob/main/LICENSE).

#### 3. CodeLead — `emischorr/codelead`

| Field | Value |
|-------|--------|
| URL | https://github.com/emischorr/codelead |
| License | **Elastic License 2.0** (source-available; **no** offering as hosted SaaS to third parties; license-key feature for container execution) |
| Stars | **1** |
| Created / last push | 2026-08-13 / 2026-09-02 |
| Packaging | **Docker Compose** under `deployment/` |

**Implements:** Human-in-the-loop product board (Planning→Running→Review→Done); **Claude Code + Codex via ACP**; Anthropic/OpenAI/Ollama; git worktrees + branches; cost/token tracking; budgets; encrypted credentials at rest (`ENCRYPTION_KEY`); LiveView; forge-agnostic local git merge/PR open. Auth roles stored but **README admits RBAC not enforced**. No Slack/Jira bots described. Cursor CLI / OpenRouter as harnesses: not primary.

**Completeness vs concept:** **High UX maturity for HITL; ~50% of concept** (strong review/cost; weak open multi-tenant/RBAC/forge webhooks).
**Fork base?** **Poor for OSS Apache product**—ELv2 blocks competing hosted offerings and is not OSI. Cherry-pick *ideas* (HITL columns, cost hold, worktree isolation).

Sources: [README](https://github.com/emischorr/codelead/blob/main/README.md), [LICENSE.txt](https://github.com/emischorr/codelead/blob/main/LICENSE.txt).

#### 4. ZenHive Harness — `ZenHive/harness`

| Field | Value |
|-------|--------|
| URL | https://github.com/ZenHive/harness |
| License | README says “MIT (or your preferred)” — **no LICENSE file found (404)** → treat as **unverified / unclear** |
| Stars | **2** |
| Created / last push | 2026-05-24 / 2026-09-22 |
| Size | ~34 MB git |

**Implements:** OTP multi-project node; **Oban** queue-per-project; `gen_statem` run lifecycle (implement→commit→review→settle); adapters for **Claude Code, Cursor, Codex, Grok, Antigravity, Pi**; **git worktrees**; cross-family reviewer; LiveView dashboard + Oban Web + **native MCP** on `:4018`; Tidewave MCP. Primary user is an **AI orchestrator**, not a team forge UI. No GitHub App/@mention product, no GitLab team RBAC, no Slack/Jira product integrations in README.

**Completeness vs concept:** **Strong engine (~40–50%); weak team/forge product.**
**Fork base?** Interesting for adapter/`gen_statem` patterns. License haze + tiny community + AI-driver UX ≠ Dominic’s team control plane.

Sources: [README](https://github.com/ZenHive/harness/blob/main/README.md).

#### 5. TurboKanban — `eadz/turbokanban`

| Field | Value |
|-------|--------|
| URL | https://github.com/eadz/turbokanban |
| License | **None bundled** (README: “add one — none is currently bundled”) |
| Stars | **0** |
| Created / last push | 2026-05-10 / 2026-05-10 (single-day spike; **stale**) |
| DB | **No database** — markdown tickets on disk |

**Implements:** LiveView kanban; drag to In Progress → PTY terminal via `script(1)` + xterm.js; **configurable CLI template** (Claude/Codex/Aider/Cursor/gemini); Claude cost panel if Claude transcripts exist. No Oban, no PR automation, no GitHub/GitLab apps, no multi-user, no Docker sandbox, no API product.

**Completeness vs concept:** **~15%** (personal agent launcher).
**Fork base?** No—toy scope, no license, inactive.

Sources: [README](https://github.com/eadz/turbokanban/blob/main/README.md).

#### 6. Ankole — `AgentBull/ankole`

| Field | Value |
|-------|--------|
| URL | https://github.com/AgentBull/ankole |
| License | **Apache-2.0** (verified LICENSE file) |
| Stars | **77** |
| Created / last push | 2026-04-19 / 2026-09-23 (active; ~299 commit pages) |
| Stack | Phoenix/OTP control plane + Bun Agent Computer + Rust kernel; React console |

**Implements:** Enterprise **workforce / “Company Brain”** agent harness: Virtual Actors, SignalsGateway (Slack/Teams/Feishu/…), AIGateway (OpenAI/Claude/OpenRouter/…), AuthZ, token quotas, bubblewrap workers, PostgreSQL. **Not** a GitHub/GitLab coding-agent control plane: no first-class Claude Code/Cursor CLI/Codex repo→PR loop in the product framing. Overlap is **OTP control-plane craft**, not Dominic’s domain model.

**Completeness vs concept:** **Low product fit (~20%); high infra inspiration.**
**Fork base?** Wrong product to fork; optional idea mining for actors/signals.

Sources: [README](https://github.com/AgentBull/ankole/blob/main/README.md), [LICENSE](https://github.com/AgentBull/ankole/blob/main/LICENSE).

#### 7. Building blocks (in scope as libraries, not full products)

| Package / repo | Role | License |
|----------------|------|---------|
| [agentjido/jido_harness](https://github.com/agentjido/jido_harness) (~20★, Apache-2.0) | Supervised normalized runtime for **Amp, Claude Code, Codex, Cursor CLI, Gemini, Grok, Kimi, OpenCode, Pi, Z.AI** via ACP; run/session/stream APIs. Explicitly **not** a durable job system or workspace provisioner. | Apache-2.0 |
| [hex.pm/claude_agent_sdk](https://hex.pm/packages/claude_agent_sdk) (MIT) | Elixir SDK over Claude Code CLI | MIT |
| [hex.pm/claude_code](https://hex.pm/packages/claude_code) (MIT) | Alternate Claude Code Elixir SDK (OTP sessions) | MIT |
| [elixir-vibe/vibe](https://github.com/elixir-vibe/vibe), [matteing/opal](https://github.com/matteing/opal) | BEAM-native coding *agents* (own loops), not multi-CLI forge control planes | MIT |

---

### (a) Ranking by completeness vs this concept

1. **Camelot** — Closest end-to-end Elixir *product*: LiveView board, Oban, Claude Code + Codex, GitHub issues/PRs, streaming, Docker Compose. Gaps: GPL-2.0, weak multi-user, no GitLab/Cursor-first-class, webhooks incomplete.
2. **CodeLead** — Rich HITL + cost + worktrees + ACP harnesses + Compose, but **ELv2** and immature authz; not a clean OSS fork base.
3. **OpenAI Symphony** — Production-grade *pattern* for tracker→workspace→agent; Apache-2.0; but **Codex-only**, preview, not team BYO-CLI Git product.
4. **ZenHive Harness** — Best multi-CLI OTP engine (includes Cursor); MCP-native; unclear license; not forge/team UI.
5. **Ankole** — Serious Elixir control plane, wrong domain (workforce chat agents).
6. **TurboKanban** — Personal PTY launcher; incomplete.
7. **jido_harness / Hex SDKs** — Libraries to *compose into* a greenfield, not competitors.

---

### (b) Feature matrix

Legend: **Y** = yes (verified in repo/docs), **P** = partial, **N** = no / not claimed, **U** = unverified.

| Feature | Camelot | CodeLead | Symphony | ZenHive Harness | Ankole | TurboKanban | OpenHands OSS | OpenHands Ent |
|---------|---------|----------|----------|-----------------|--------|-------------|---------------|---------------|
| LiveView / web UI | Y | Y | P (opt dashboard) | Y | Y (React+Phoenix) | Y | Y (TS Canvas) | Y |
| REST/JSON API | P | P | Y | P (MCP) | Y | N | Y | Y |
| Job orchestration (Oban/OTP) | Y Oban | Y OTP | Y OTP | Y Oban | Y OTP/actors | N | Y | Y |
| Docker / sandbox isolation | P (runner images) | P (devcontainer paid tier) | P (Codex sandbox) | P (worktrees) | Y (workers/bwrap) | N | Y | Y |
| GitHub clone/branch/PR | Y | Y | Y (Issues+tools) | P (git/worktree) | N (not forge-native) | N | Y | Y |
| GitLab | N | P (generic git) | Y (tracker) | N | N | N | P | Y |
| Webhooks / @mentions | P (roadmap) | N | N (poll) | N | Y (chat) | N | P | Y |
| Claude Code backend | Y | Y | N | Y | N (API models) | P (template) | Y (ACP) | Y |
| Cursor CLI backend | N | N | N | Y | N | P (template) | N | N |
| Codex backend | Y | Y | Y | Y | P (jobs mention) | P | Y (ACP) | Y |
| OpenRouter / API loop | N | P (API models) | N | N | Y | N | Y | Y |
| Multi-user / teams / RBAC | P (roadmap) | P (roles unused) | N | N | Y | N | N | Y |
| Secrets encrypted at rest | U | Y | P (env) | U | U | N | Y | Y |
| Slack | N | N | N | N | Y | N | P | Y |
| Jira | N | N | Y (tracker) | N | N | N | P Cloud | Y DC |
| Live log streaming | Y | Y | P | Y | Y | Y (PTY) | Y | Y |
| Follow-ups | P | Y | P | P | Y | Y (PTY) | Y | Y |
| Cost tracking | U | Y | U | U | Y (quotas) | P (Claude) | P | Y |
| Tests | Y | Y | Y | Y | Y | U | Y | Y |
| Compose / Helm packaging | Y Compose | Y Compose | Burrito bins | N | Compose (devkit) | Releases | Compose | Helm |
| OSI-friendly license | N (GPL-2) | N (ELv2) | Y (Apache-2) | U | Y (Apache-2) | N (none) | Y (MIT) | N (PolyForm) |

---

### (c) Recommendation

**Do not fork any single Elixir prototype as the product base.** None is both (1) license-compatible with an Apache-2.0 core + commercial enterprise plan and (2) complete on GitHub+GitLab team control plane + Claude Code + Cursor CLI + OpenRouter.

**Preferred path: greenfield Elixir/Phoenix control plane**, with selective reuse:

1. **Depend on or vendor patterns from `jido_harness`** (Apache-2.0) for CLI/ACP adapter normalization—or write a thinner Behaviour and optionally use Hex `claude_agent_sdk` / `claude_code` for Claude Code only.
2. **Steal designs (not GPLv2 code) from Camelot** for LiveView board + session streaming UX.
3. **Steal architecture ideas from Symphony SPEC** for tracker polling, workspace lifecycle, and concurrency—without adopting Codex-only lock-in.
4. **Steal HITL/cost/worktree ideas from CodeLead** without forking ELv2.
5. **Ignore TurboKanban** as a base; skim Ankole only for OTP actor/signal inspiration.

**If Dominic prefers contribute-over-build:** Camelot is the only *community* Elixir app close enough to extend—but only if **GPL-2.0** is acceptable (it is not, under the Apache-2.0 dual-license recommendation in §9 of this doc). Symphony is better as a **spec reference** than a fork. OpenHands remains the strongest *existing* platform overall (Python), with the license/Cursor/GitLab gaps documented in the OpenHands deep dive—Elixir greenfield is justified only if the BEAM/ops + multi-CLI + permissive self-host story is non-negotiable.

### Unverified (this section)

- Exact contributor counts (API not always returning full contributor lists here).
- Cloak/encryption internals in Camelot, Harness, Ankole (not fully traced in source beyond README claims).
- ZenHive Harness SPDX license (no LICENSE file).
- Whether Camelot `runner-images` equal true multi-tenant sandbox isolation.
- Whether Symphony’s GitLab tracker equals full MR/@mention GitLab App UX.
- Depth of Cursor adapter in ZenHive Harness (claimed in README; adapter code not line-audited).
- Activity of `mpakus/cuckoding.com` (appeared in code search; not fully reviewed—likely out of scope / niche).
