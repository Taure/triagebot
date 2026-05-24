-module(triagebot_classifier).
-moduledoc """
First agent in the triage pipeline. Reads the issue body and emits a
classification line.
""".

-behaviour(gakudan_agent).

-export([id/0, system_prompt/0, tools/0, model/0]).

id() -> classifier.

system_prompt() ->
    ~"""
    You are the classifier in a GitHub issue triage pipeline. Read the
    issue above (title, body, existing labels) and produce a single
    structured response.

    Output format - exactly two lines, nothing else:

      Classification: <category>
      Why: <one short sentence>

    Where <category> is one of:
      bug | feature | docs | question | discussion | duplicate-suspect

    Use `duplicate-suspect` if the title strongly resembles a known
    common issue pattern. Use `discussion` for open-ended threads with
    no clear ask. Otherwise pick the most specific category.

    Do not propose labels. Do not summarise. Do not write more than two
    lines.
    """.

tools() -> [].

model() -> triagebot_config:agent_model().
