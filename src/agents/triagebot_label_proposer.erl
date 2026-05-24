-module(triagebot_label_proposer).
-moduledoc """
Fourth agent. Reads the issue + all prior triage turns and proposes a
set of labels.
""".

-behaviour(gakudan_agent).

-export([id/0, system_prompt/0, tools/0, model/0]).

id() -> label_proposer.

system_prompt() ->
    iolist_to_binary([
        ~"""
        You are the label proposer. The previous turns classified the
        issue, scoped its severity, and checked for duplicates. Now
        propose labels for the maintainers to apply.

        Output exactly ONE line:

          Labels: <label>, <label>, <label>

        Pick **only** from the labels that already exist in this repo.
        Do not invent new labels - applying a label the repo has not
        defined will fail.

        """,
        render_label_inventory(triagebot_config:repo_labels()),
        ~"""

        Conventions:

        - If the repo defines `claude-try`, apply it only when the
          issue is `bug` + (`minor` or `major`) + `self-contained` AND
          has a clear reproducer. This label is the signal for a
          separate claude-code-action workflow to attempt an auto-fix.
        - If the repo defines `needs-info`, apply it when the body
          lacks enough detail to act on.
        - Do not propose `triaged` - that label is added automatically
          by the bot when the triage comment is posted.

        One line, no commentary.
        """
    ]).

tools() -> [].

model() -> triagebot_config:agent_model().

%% --- internal ---

render_label_inventory([]) ->
    ~"""
    Labels defined in this repo could not be fetched. Fall back to
    this base vocabulary - only propose labels from it that you are
    confident the repo already defines:

      bug, feature, docs, question, discussion, duplicate-suspect,
      cosmetic, minor, major, blocker,
      self-contained, cross-cutting,
      good-first-issue, needs-info, claude-try
    """;
render_label_inventory(Labels) ->
    Lines = [render_label(L) || L <- Labels],
    iolist_to_binary([
        ~"Labels defined in this repo (pick only from this list):\n\n",
        lists:join(~"\n", Lines)
    ]).

render_label(#{name := N, description := ~""}) ->
    [~"  - `", N, ~"`"];
render_label(#{name := N, description := D}) ->
    [~"  - `", N, ~"`: ", D].
