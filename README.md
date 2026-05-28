# triagebot

[![CI](https://github.com/Taure/triagebot/actions/workflows/ci.yml/badge.svg)](https://github.com/Taure/triagebot/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/Taure/triagebot)](LICENSE)
[![Erlang](https://img.shields.io/badge/erlang-28%2B-blue)](.tool-versions)

Multi-agent GitHub issue triage bot built on [Nova](https://github.com/novaframework/nova)
and the [gakudan](https://github.com/Taure/gakudan) ecosystem.

Reference consumer for `gakudan`, `gakudan_tickets`, `gakudan_tickets_github`,
and `gakudan_metrics`. Dog-foods on the gakudan repo itself.

## What it does

When a GitHub Issue is opened or labeled, triagebot:

1. Receives the webhook on `POST /webhook/github`.
2. Verifies the `X-Hub-Signature-256` HMAC against the shared secret.
3. Hands the parsed issue to a five-agent gakudan pipeline:
   `classifier` → `scoper` → `dup_detector` → `label_proposer` → `summariser`.
4. The `classifier` and `scoper` agents use a `read_repo_file` tool to
   ground themselves in `CLAUDE.md`, `README.md`, or the source file an
   issue links to. The `dup_detector` agent uses `search_issues` to
   scan the repo for likely duplicates. The `label_proposer` picks
   from the labels actually defined in the repo (fetched once at
   startup).
5. The `summariser` produces a structured Markdown comment that gets
   posted on the issue.
6. The `label_proposer`'s output is parsed for label names and applied
   to the issue (plus a `triaged` marker).

Already-`triaged` issues are skipped to avoid loops.

## Architecture

```
GitHub Issues webhook
   |
   v
Nova /webhook/github controller
   - HMAC signature verification
   - parse_webhook -> {Event, Ticket}
   |
   v
triagebot_runner:dispatch (spawn-and-forget)
   |
   v
gakudan run with 5 agents + 1 search tool
   - LLM: Anthropic (with prompt caching) or Gemini
   |
   v
gakudan_tickets_github
   - post_comment
   - apply_labels (incl. "triaged")
```

Telemetry from gakudan flows into `gakudan_metrics` which exposes a
`/metrics` endpoint on a separate port (default `9568`) for Prometheus.

## Setup

### 1. Create a GitHub App

Settings → Developer settings → GitHub Apps → New GitHub App.

- **Webhook URL**: `https://<your-deploy>/webhook/github`
- **Webhook secret**: a long random string (keep it for env vars below)
- **Subscribe to events**: Issues
- **Permissions**:
  - Repository → Issues: Read & write
  - Repository → Metadata: Read (default)

Install the App on the target repository. Note the App ID, generate a
private key (PEM), and note the installation ID from the install URL.

### 2. Environment variables

Required:

| Var | Description |
| --- | --- |
| `TRIAGEBOT_WEBHOOK_SECRET` | Shared secret you set in the GitHub App webhook config |
| `TRIAGEBOT_REPO_OWNER` | e.g. `Taure` |
| `TRIAGEBOT_REPO_NAME` | e.g. `gakudan` |

GitHub auth (one of):

| Var | Description |
| --- | --- |
| `TRIAGEBOT_GITHUB_TOKEN` | Personal Access Token (single user mode) |
| `TRIAGEBOT_GITHUB_APP_ID` + `TRIAGEBOT_GITHUB_APP_PRIVATE_KEY_PEM` + `TRIAGEBOT_GITHUB_INSTALLATION_ID` | GitHub App mode |

LLM backend (one of):

| Var | Description |
| --- | --- |
| `ANTHROPIC_API_KEY` | Use Anthropic; default model `claude-sonnet-4-6` |
| `GEMINI_API_KEY` | Use Gemini; default model `gemini-2.5-flash` |

Optional:

| Var | Default | Description |
| --- | --- | --- |
| `TRIAGEBOT_PORT` | `8080` | Nova HTTP listener |
| `TRIAGEBOT_METRICS_PORT` | `9568` | Prometheus /metrics; set to `""` to disable |
| `TRIAGEBOT_AGENT_MODEL` | per-backend | Override agent model |
| `TRIAGEBOT_POLICY_PATH` | `priv/TRIAGE.md` | Filesystem path to the triage-policy file fed to every agent |

### Triage policy

Every triage run is fed a shared **repository triage context** before the
issue: the contents of a triage-policy file plus the repo's label
taxonomy. The policy teaches the agents how *this* project triages -
what the categories mean, the severity rubric, which labels to use,
escalation rules - and agents follow it where it conflicts with their
built-in defaults.

The policy ships in the release at `priv/TRIAGE.md`; edit that file and
redeploy, or point `TRIAGEBOT_POLICY_PATH` at another file. A missing
file is fine - agents fall back to their built-in defaults. To reload
without a redeploy, call `triagebot_config:refresh_triage_policy()` from
a remote shell.

Each issue also carries its high-signal GitHub fields into the context:
contributor association (e.g. `FIRST_TIME_CONTRIBUTOR`), reaction count,
comment count, milestone, and assignees.

### 3. Local development with PAT

```bash
export TRIAGEBOT_WEBHOOK_SECRET=$(openssl rand -hex 32)
export TRIAGEBOT_REPO_OWNER=Taure
export TRIAGEBOT_REPO_NAME=gakudan
export TRIAGEBOT_GITHUB_TOKEN=ghp_...
export ANTHROPIC_API_KEY=sk-ant-...
rebar3 shell
```

Hit `/health` from another terminal: `curl http://localhost:8080/health`.

### 4. Deploy

Triagebot ships a multi-stage `Dockerfile` that produces a small,
portable container. Build and run it anywhere a container runs:

```bash
docker build -t triagebot .
docker run --rm \
    -p 8080:8080 -p 9568:9568 \
    --env-file .env \
    triagebot
```

Point your GitHub App webhook at `https://<your-host>/webhook/github`.
That's it.

## What's in v0.1

- Nova HTTP shell with webhook + health controllers
- 5 agent modules + 2 tools (`search_issues`, `read_repo_file`)
- Spawn-and-forget async (BEAM process per webhook) so the response
  returns 202 immediately while triage runs in the background
- GitHub App or PAT auth (via `gakudan_tickets_github` v0.1.2+)
- Repo-context awareness: a bundled triage policy (`priv/TRIAGE.md`) +
  the repo's actual label taxonomy + each issue's contributor/reaction/
  milestone signals are fed to every agent; classifier + scoper can also
  read repo files on demand
- Prometheus `/metrics` via `gakudan_metrics`
- 20-case CT suite covering the runner helpers, agent callbacks, tool
  shapes, and dynamic prompt building

## Roadmap

**v0.2 — persistence and async safety**

- `shigoto` job queue so triage runs survive a BEAM restart and idempotency
  becomes free (the `X-GitHub-Delivery` UUID keys the queue).
- `kura` Postgres-backed `triage_runs` table for audit trail (transcript,
  posted comment id, timings).
- `/admin` endpoint listing recent triages and their outcomes.

**v0.3+ — possibilities**

- `claude-try` label gating to trigger `claude-code-action` for auto-fix
  PRs.
- `gakudan_eval` cases checked in alongside production agent prompts so
  PR review against the bot's behaviour is gated.
- Multi-repo / multi-installation support.

## License

MIT.
