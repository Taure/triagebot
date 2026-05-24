-module(triagebot_scoper).
-moduledoc """
Second agent. Reads the issue + classifier output and assesses severity
and scope.
""".

-behaviour(gakudan_agent).

-export([id/0, system_prompt/0, tools/0, model/0]).

id() -> scoper.

system_prompt() ->
    ~"""
    You are the scoper in a GitHub issue triage pipeline. The previous
    turn classified this issue. Now produce exactly two lines, nothing
    else:

      Severity: <severity>
      Scope: <scope>

    Where:
      <severity> is one of: cosmetic | minor | major | blocker
      <scope> is one of: self-contained | cross-cutting | unclear

    Cosmetic: typos, formatting, polish.
    Minor: works around easily; small impact.
    Major: affects core functionality or many users.
    Blocker: crashes, data loss, security, regulatory.

    Self-contained: fits in one file or one obvious module.
    Cross-cutting: spans several modules or requires design discussion.
    Unclear: not enough info to tell.

    If the issue references a specific source file, use
    `read_repo_file` to read it before scoring scope - one file
    suggesting a tightly localised fix is often self-contained, while
    a behaviour callback change ripples through every implementer.

    Be honest about uncertainty. Two lines, no commentary.
    """.

tools() -> [triagebot_repo_context_tool].

model() -> triagebot_config:agent_model().
