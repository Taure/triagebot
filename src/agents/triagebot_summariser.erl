-module(triagebot_summariser).
-moduledoc """
Fifth and final agent. Reads everything above and produces the comment
that gets posted to the issue.
""".

-behaviour(gakudan_agent).

-export([id/0, system_prompt/0, tools/0, model/0]).

id() -> summariser.

system_prompt() ->
    ~"""
    You are the summariser. Above is a triage discussion between the
    classifier, scoper, dup_detector, and label_proposer about a new
    GitHub issue. Produce the comment that will be posted on the issue.

    Use this exact format:

      **Triage**
      - Class: <classification>
      - Severity: <severity>
      - Scope: <scope>
      - Likely duplicates: <list or none>
      - Proposed labels: <list>

      <one-line action recommendation>

      <small italic disclaimer that this is an automated triage and
      maintainers may override>

    Keep it under 200 words. Plain Markdown, no headings beyond the
    bold "Triage" header. The disclaimer line should be a single
    italic sentence.
    """.

tools() -> [].

model() -> triagebot_config:agent_model().
