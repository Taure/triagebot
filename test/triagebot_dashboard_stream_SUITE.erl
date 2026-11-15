-module(triagebot_dashboard_stream_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_testcase/2, end_per_testcase/2]).
-export([
    transcript_keeps_carriage_returns_inside_one_event/1,
    appended_entry_keeps_carriage_returns_inside_one_event/1
]).

-define(RUN_ID, ~"run-with-carriage-returns").

all() ->
    [
        transcript_keeps_carriage_returns_inside_one_event,
        appended_entry_keeps_carriage_returns_inside_one_event
    ].

init_per_testcase(_Case, Config) ->
    {ok, _} = application:ensure_all_started([cowboy, telemetry]),
    {ok, Registry} = gakudan_registry:start_link(),
    {ok, Stats} = gakudan_liveboard_stats:start_link(),
    {ok, Blackboard} = gakudan_blackboard:start_link(?RUN_ID),
    [{blackboard, Blackboard}, {started, [Stats, Registry, Blackboard]} | Config].

end_per_testcase(_Case, Config) ->
    [gen_server:stop(Server) || Server <- ?config(started, Config), is_process_alive(Server)],
    ok.

transcript_keeps_carriage_returns_inside_one_event(Config) ->
    Blackboard = ?config(blackboard, Config),
    {ok, _} = gakudan_blackboard:append(
        Blackboard, user, ~"Steps to reproduce:\r\n1. open the page\r2. press save"
    ),
    Stream = open_run_stream(Blackboard),
    [{Type, Html}] = received_patches(written_frame(Stream)),
    ?assertEqual(~"datastar-patch-elements", Type),
    ?assertMatch(
        {_, _},
        binary:match(
            Html,
            ~"<div class=\"body-text\">Steps to reproduce:\n1. open the page\n2. press save</div>"
        )
    ),
    close(Stream).

appended_entry_keeps_carriage_returns_inside_one_event(Config) ->
    Blackboard = ?config(blackboard, Config),
    Stream = open_run_stream(Blackboard),
    _Transcript = written_frame(Stream),
    _Rail = written_frame(Stream),
    {ok, _} = gakudan_blackboard:append(Blackboard, {agent, classifier}, ~"bug\r\rminor"),
    [{Type, Html}] = received_patches(written_frame(Stream)),
    ?assertEqual(~"datastar-patch-elements", Type),
    ?assertMatch({_, _}, binary:match(Html, ~"<div class=\"body-text\">bug\n\nminor</div>")),
    close(Stream).

open_run_stream(Blackboard) ->
    Req = #{pid => self(), streamid => 1, method => ~"GET"},
    Source = {run, ?RUN_ID, Blackboard},
    Stream = spawn_link(fun() ->
        gakudan_liveboard_sse:handle_stream({stream, 200, #{}, Source}, undefined, Req)
    end),
    receive
        {{_Connection, 1}, {headers, 200, _Headers}} -> Stream
    after 1000 ->
        error(no_headers_written)
    end.

close(Stream) ->
    unlink(Stream),
    exit(Stream, kill).

written_frame(Stream) ->
    receive
        {{_Connection, 1}, {data, Stream, nofin, Frame}} ->
            Stream ! {data_ack, self()},
            Frame
    after 1000 ->
        error(no_frame_written)
    end.

%% Reads a stream the way an SSE client does: a line ends at CRLF, CR or LF
%% and a blank line dispatches the event. Returns the type of each event
%% with the HTML a Datastar client rebuilds from its `elements` lines.
-spec received_patches(iodata()) -> [{binary(), binary()}].
received_patches(Frame) ->
    Lines = binary:split(iolist_to_binary(Frame), [~"\r\n", ~"\r", ~"\n"], [global]),
    dispatched_events(Lines, ~"", []).

-spec dispatched_events([binary()], binary(), [binary()]) -> [{binary(), binary()}].
dispatched_events([], _Type, _ElementsLines) ->
    [];
dispatched_events([~"" | Rest], Type, ElementsLines) ->
    dispatched_event(Type, ElementsLines) ++ dispatched_events(Rest, ~"", []);
dispatched_events([Line | Rest], Type, ElementsLines) ->
    case binary:split(Line, ~": ") of
        [~"event", NewType] ->
            dispatched_events(Rest, NewType, ElementsLines);
        [~"data", Data] ->
            dispatched_events(Rest, Type, ElementsLines ++ elements_line(Data));
        _OtherLine ->
            dispatched_events(Rest, Type, ElementsLines)
    end.

-spec dispatched_event(binary(), [binary()]) -> [{binary(), binary()}].
dispatched_event(_Type, []) -> [];
dispatched_event(Type, HtmlLines) -> [{Type, binary:join(HtmlLines, ~"\n")}].

-spec elements_line(binary()) -> [binary()].
elements_line(Data) ->
    case binary:split(Data, ~" ") of
        [~"elements", HtmlLine] -> [HtmlLine];
        _OtherData -> []
    end.
