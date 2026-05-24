-module(triagebot_runner_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0]).
-export([
    extract_labels_from_summariser_line/1,
    extract_labels_handles_no_labels_line/1,
    extract_labels_trims_whitespace/1,
    extract_agent_turn_returns_last_match/1,
    extract_agent_turn_returns_default_when_missing/1
]).

all() ->
    [
        extract_labels_from_summariser_line,
        extract_labels_handles_no_labels_line,
        extract_labels_trims_whitespace,
        extract_agent_turn_returns_last_match,
        extract_agent_turn_returns_default_when_missing
    ].

extract_labels_from_summariser_line(_Config) ->
    Entries = [
        #{role => user, content => ~"go"},
        #{
            role => {agent, label_proposer},
            content => ~"Labels: bug, minor, claude-try"
        }
    ],
    Labels = triagebot_runner_helpers:extract_proposed_labels(Entries),
    ?assertEqual([~"bug", ~"minor", ~"claude-try"], Labels).

extract_labels_handles_no_labels_line(_Config) ->
    Entries = [#{role => {agent, label_proposer}, content => ~"some other text"}],
    ?assertEqual([], triagebot_runner_helpers:extract_proposed_labels(Entries)).

extract_labels_trims_whitespace(_Config) ->
    Entries = [
        #{
            role => {agent, label_proposer},
            content => ~"Labels:    bug ,   minor ,claude-try"
        }
    ],
    Labels = triagebot_runner_helpers:extract_proposed_labels(Entries),
    ?assertEqual([~"bug", ~"minor", ~"claude-try"], Labels).

extract_agent_turn_returns_last_match(_Config) ->
    Entries = [
        #{role => {agent, classifier}, content => ~"first classifier turn"},
        #{role => {agent, scoper}, content => ~"scoper output"},
        #{role => {agent, classifier}, content => ~"second classifier turn"}
    ],
    Got = triagebot_runner_helpers:extract_agent_turn(Entries, classifier, ~""),
    ?assertEqual(~"second classifier turn", Got).

extract_agent_turn_returns_default_when_missing(_Config) ->
    Entries = [#{role => user, content => ~"x"}],
    ?assertEqual(
        ~"default-here",
        triagebot_runner_helpers:extract_agent_turn(Entries, summariser, ~"default-here")
    ).
