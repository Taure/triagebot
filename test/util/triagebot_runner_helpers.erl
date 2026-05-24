-module(triagebot_runner_helpers).
-moduledoc """
Re-exports of `triagebot_runner` private functions for testing.

We avoid exporting the helpers from the production module (they're
implementation detail) by routing tests through this small shim.
""".

-export([extract_proposed_labels/1, extract_agent_turn/3]).

%% Mirror of triagebot_runner:extract_proposed_labels/1 for testing.
extract_proposed_labels(Entries) ->
    Text = extract_agent_turn(Entries, label_proposer, ~""),
    case re:run(Text, "Labels:\\s*([^\\n]+)", [{capture, [1], binary}]) of
        {match, [Line]} ->
            Parts = binary:split(Line, ~",", [global]),
            [trim(P) || P <- Parts, trim(P) =/= ~""];
        nomatch ->
            []
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

trim(B) ->
    list_to_binary(string:trim(binary_to_list(B))).
