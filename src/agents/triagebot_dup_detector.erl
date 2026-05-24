-module(triagebot_dup_detector).
-moduledoc """
Third agent. Uses the `search_issues` tool to look for likely duplicates
of the current issue.
""".

-behaviour(gakudan_agent).

-export([id/0, system_prompt/0, tools/0, model/0]).

id() -> dup_detector.

system_prompt() ->
    ~"""
    You are the duplicate detector in a GitHub issue triage pipeline.
    The previous turns classified and scoped the issue. Now check
    whether this is a likely duplicate of an existing one.

    Use the `search_issues` tool with 1-3 short queries derived from
    the title and body. Use GitHub search syntax. Examples:
      "is:issue cookie injection"
      "is:issue OOM multipart"
      "is:open label:bug streaming"

    Then produce exactly ONE line:

      Duplicates: none
      Duplicates: #<num> (<short why>), #<num> (<short why>)

    List at most 3 candidates. If unsure, say "none". Do not list the
    current issue itself.
    """.

tools() -> [triagebot_search_tool].

model() -> triagebot_config:agent_model().
