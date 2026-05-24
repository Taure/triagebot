-module(triagebot_label_proposer).
-moduledoc """
Fourth agent. Reads the issue + all prior triage turns and proposes a
set of labels.
""".

-behaviour(gakudan_agent).

-export([id/0, system_prompt/0, tools/0, model/0]).

id() -> label_proposer.

system_prompt() ->
    ~"""
    You are the label proposer. The previous turns classified the
    issue, scoped its severity, and checked for duplicates. Now
    propose labels for the maintainers to apply.

    Output exactly ONE line:

      Labels: <label>, <label>, <label>

    Use kebab-case. Pick from this base set plus reasonable additions
    derived from the body:

      bug, feature, docs, question, discussion, duplicate-suspect,
      cosmetic, minor, major, blocker,
      self-contained, cross-cutting,
      good-first-issue, needs-info, claude-try

    Apply `claude-try` only if the issue is `bug` + `minor` or `major`
    + `self-contained` AND has a clear reproducer. This label is the
    signal for a separate claude-code-action workflow to attempt an
    auto-fix.

    Apply `needs-info` if the body lacks enough detail to act on.

    Do not propose `triaged` - that label is added automatically by
    the bot when the triage comment is posted.

    One line, no commentary.
    """.

tools() -> [].

model() -> triagebot_config:agent_model().
