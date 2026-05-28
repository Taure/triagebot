# Triage policy - gakudan

This file ships in triagebot's release (`priv/TRIAGE.md`) and is fed to
every triage agent as authoritative context. It is tuned for
[Taure/gakudan](https://github.com/Taure/gakudan): multi-agent
collaboration primitives for the BEAM (Erlang/OTP, single-node).

Edit it to change how the bot triages, then redeploy (or call
`triagebot_config:refresh_triage_policy/0` from a remote shell). Agents
follow this policy wherever it conflicts with their built-in defaults.

## Classification

- `bug`: behaviour contrary to documented intent (a crash, a wrong
  result, a leak, a supervision-tree fault).
- `feature`: a net-new primitive, behaviour, LLM/MCP backend, or API.
- `docs`: documentation, README, or ADR text only - no code behaviour
  change.
- `question`: a usage question with a concrete answer.
- `discussion`: open-ended design conversation with no single clear ask.
- `duplicate-suspect`: strongly resembles an existing issue.

## Severity

- `blocker`: crash, data loss, security, or a broken public behaviour
  contract (a `gakudan_agent`/`router`/`tool`/`llm`/`checkpointer`
  callback, telemetry event, or the MCP wire format - all semver-locked).
- `major`: breaks core orchestration (run lifecycle, fanout, resume,
  streaming) or affects many consumers.
- `minor`: small impact, easy to work around.
- `cosmetic`: typos, formatting, log wording.

Treat anything mentioning credentials, API keys, prompt-injection, or
data leakage as at least `major` and label it `security`.

## Scope

- `self-contained`: one module or one obvious function.
- `cross-cutting`: changes a public behaviour callback (ripples through
  every implementer), a telemetry event (requires a `gakudan_metrics`
  lockstep update), or the MCP/stream message shapes. These are
  semver-relevant and usually need an ADR (`docs/adr/`, Nygard format).
- `unclear`: not enough information to tell.

## Labels

- `needs-info`: the body lacks a reproducer, OTP version, or enough
  detail to act on. Prefer this over guessing.
- `good-first-issue`: `self-contained` + `minor` + well-described.
- `claude-try`: apply only when the issue is `bug` + (`minor` or
  `major`) + `self-contained` AND has a clear reproducer. This is the
  signal for the claude-code-action workflow to attempt an auto-fix.
  Do NOT apply it to anything touching a public behaviour, telemetry,
  the MCP wire format, or anything that needs an ADR first.

## Scope guardrails (out of scope by design)

gakudan is **single-node by design**. Requests for multi-node
distribution, clustering, or distributed-Erlang fanout are out of scope:
classify as `discussion`, keep severity at most `minor`, and say so
plainly rather than proposing an implementation.

## Contributor signal

First-time contributors (`FIRST_TIME_CONTRIBUTOR`) get a friendlier tone
and an explicit pointer to what extra detail would help (a reproducer,
the OTP version, the backend in use). Issues filed by maintainers
(`MEMBER`, `OWNER`) usually already carry intentional labels - respect
them.
