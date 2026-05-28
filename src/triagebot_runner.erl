-module(triagebot_runner).
-moduledoc """
Bridges a verified webhook event to a gakudan triage run.

`dispatch/2` is invoked from the webhook controller. It spawns a
detached Erlang process so the controller can return 202 immediately
while the LLM-bound work continues in the background.

Only `issue_opened` and `issue_labeled` events are processed. Other
events (closed, edited, etc.) are ignored at the runner level to keep
LLM cost predictable and avoid re-triaging on every edit.

If the issue already carries the `triaged` label, we skip - this gives
human maintainers a manual override (label, fix, push, no bot retriage)
and protects against the bot looping on its own label updates.
""".

-include_lib("kernel/include/logger.hrl").

-export([dispatch/2, run_triage/1]).

-define(AGENTS, [
    triagebot_classifier,
    triagebot_scoper,
    triagebot_dup_detector,
    triagebot_label_proposer,
    triagebot_summariser
]).

-define(TRIAGED_LABEL, ~"triaged").
-define(CLAUDE_TRY_LABEL, ~"claude-try").

-spec dispatch(atom(), gakudan_tickets:ticket()) -> ok.
dispatch(Event, Ticket) when Event =:= issue_opened; Event =:= issue_labeled ->
    case lists:member(?TRIAGED_LABEL, maps:get(labels, Ticket, [])) of
        true ->
            ?LOG_INFO(#{
                event => triage_skipped,
                reason => already_triaged,
                ticket_id => maps:get(id, Ticket)
            }),
            ok;
        false ->
            _Pid = spawn(?MODULE, run_triage, [Ticket]),
            ok
    end;
dispatch(_Other, _Ticket) ->
    ok.

-spec run_triage(gakudan_tickets:ticket()) -> ok.
run_triage(Ticket) ->
    Source = triagebot_config:github_source(),
    LlmSpec = triagebot_config:llm_backend_spec(),
    Config = #{
        agents => ?AGENTS,
        router => {gakudan_router_round_robin, #{rounds => 1}},
        llm => LlmSpec,
        max_turns => length(?AGENTS) + 2
    },
    case gakudan:start_run(Config) of
        {ok, _Sup, RunId} ->
            try do_run(RunId, Ticket, Source) of
                ok -> ok
            after
                safe_stop(RunId)
            end;
        {error, Reason} ->
            ?LOG_ERROR(#{
                event => gakudan_start_failed,
                reason => Reason,
                ticket_id => maps:get(id, Ticket)
            }),
            ok
    end.

safe_stop(RunId) ->
    try gakudan:stop(RunId) of
        _ -> ok
    catch
        _:_ -> ok
    end.

do_run(RunId, Ticket, Source) ->
    Input = triagebot_context:build_input(Ticket),
    ok = gakudan:send(RunId, Input),
    case gakudan:await(RunId, 120_000) of
        {ok, Entries} ->
            apply_triage_output(Entries, Ticket, Source);
        {error, Reason} ->
            ?LOG_ERROR(#{
                event => gakudan_await_failed,
                reason => Reason,
                ticket_id => maps:get(id, Ticket)
            }),
            ok
    end.

apply_triage_output(Entries, Ticket, Source) ->
    Id = maps:get(id, Ticket),
    Comment = extract_agent_turn(Entries, summariser, ~""),
    Labels = extract_proposed_labels(Entries),
    _ = maybe_post_comment(Source, Id, Comment),
    _ = maybe_apply_labels(Source, Id, Labels),
    _ = maybe_request_claude_implementation(Source, Id, Labels),
    ok.

maybe_post_comment(_Source, _Id, <<>>) ->
    ok;
maybe_post_comment(Source, Id, Comment) ->
    case gakudan_tickets_github:post_comment(Source, Id, Comment) of
        ok ->
            ok;
        {error, Reason} ->
            ?LOG_ERROR(#{event => post_comment_failed, reason => Reason, ticket_id => Id})
    end.

maybe_apply_labels(_Source, _Id, []) ->
    ok;
maybe_apply_labels(Source, Id, Labels) ->
    Final = [?TRIAGED_LABEL | Labels],
    case gakudan_tickets_github:apply_labels(Source, Id, Final) of
        ok ->
            ok;
        {error, Reason} ->
            ?LOG_ERROR(#{event => apply_labels_failed, reason => Reason, ticket_id => Id})
    end.

%% If the label_proposer asked for `claude-try`, leave a follow-up
%% comment summoning the claude-code-action workflow in the same repo.
%% The action listens on issues.labeled too, but posting an explicit
%% mention makes the chain visible in the issue thread.
maybe_request_claude_implementation(Source, Id, Labels) ->
    case lists:member(?CLAUDE_TRY_LABEL, Labels) of
        false ->
            ok;
        true ->
            Body =
                ~"@claude please implement this issue per the triage above. Open a PR closing this issue when done.",
            case gakudan_tickets_github:post_comment(Source, Id, Body) of
                ok ->
                    ?LOG_INFO(#{
                        event => claude_implementation_requested,
                        ticket_id => Id
                    });
                {error, Reason} ->
                    ?LOG_ERROR(#{
                        event => claude_request_comment_failed,
                        reason => Reason,
                        ticket_id => Id
                    })
            end
    end.

extract_agent_turn(Entries, AgentId, Default) ->
    Reversed = lists:reverse(Entries),
    find_agent_text(Reversed, AgentId, Default).

find_agent_text([], _AgentId, Default) ->
    Default;
find_agent_text([#{role := {agent, AgentId}, content := C} | _], AgentId, _Default) when
    is_binary(C)
->
    C;
find_agent_text([_ | Rest], AgentId, Default) ->
    find_agent_text(Rest, AgentId, Default).

extract_proposed_labels(Entries) ->
    Text = extract_agent_turn(Entries, label_proposer, ~""),
    case re:run(Text, "Labels:\\s*([^\\n]+)", [{capture, [1], binary}]) of
        {match, [Line]} ->
            Parts = binary:split(Line, ~",", [global]),
            [trim(P) || P <- Parts, trim(P) =/= ~""];
        nomatch ->
            []
    end.

trim(B) ->
    list_to_binary(string:trim(binary_to_list(B))).
