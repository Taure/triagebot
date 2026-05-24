-module(triagebot_search_tool).
-moduledoc """
gakudan tool that searches the configured GitHub repo for issues
matching a query, returning a short text summary the LLM can read.

The active GitHub source_ref is read from `triagebot_config`
(persistent_term) because gakudan tools run inside a turn-worker
process spawned by the run state machine, with no parameter for
per-run context.
""".

-behaviour(gakudan_tool).

-export([spec/0, run/1]).

spec() ->
    #{
        name => ~"search_issues",
        description =>
            ~"""
            Search the configured GitHub repository for issues matching a GitHub
            search query (e.g. "is:issue cookie", "is:open label:bug").
            Returns up to 10 matches as a short summary text.
            """,
        input_schema => #{
            type => ~"object",
            properties => #{
                query => #{
                    type => ~"string",
                    description => ~"GitHub search syntax query."
                }
            },
            required => [~"query"]
        }
    }.

run(#{~"query" := Query}) when is_binary(Query) ->
    Source = triagebot_config:github_source(),
    case gakudan_tickets_github:search(Source, Query) of
        {ok, []} ->
            {ok, ~"No matches."};
        {ok, Tickets} ->
            Top = lists:sublist(Tickets, 10),
            Lines = [format_ticket(T) || T <- Top],
            {ok, iolist_to_binary(lists:join(~"\n", Lines))};
        {error, Reason} ->
            {error, Reason}
    end;
run(_Other) ->
    {error, invalid_input}.

format_ticket(#{id := Id, title := Title} = T) ->
    Labels = maps:get(labels, T, []),
    LabelSuffix =
        case Labels of
            [] -> ~"";
            _ -> iolist_to_binary([~" [", lists:join(~",", Labels), ~"]"])
        end,
    iolist_to_binary([~"#", Id, ~": ", Title, LabelSuffix]).
