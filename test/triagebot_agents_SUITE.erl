-module(triagebot_agents_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([
    classifier_uses_repo_context_tool/1,
    scoper_uses_repo_context_tool/1,
    dup_detector_uses_search_tool/1,
    label_proposer_has_required_callbacks/1,
    label_proposer_prompt_includes_repo_labels_when_present/1,
    label_proposer_prompt_falls_back_when_labels_empty/1,
    summariser_has_required_callbacks/1,
    all_agents_have_distinct_ids/1,
    all_system_prompts_non_empty/1
]).

-define(AGENTS, [
    triagebot_classifier,
    triagebot_scoper,
    triagebot_dup_detector,
    triagebot_label_proposer,
    triagebot_summariser
]).

all() ->
    [
        classifier_uses_repo_context_tool,
        scoper_uses_repo_context_tool,
        dup_detector_uses_search_tool,
        label_proposer_has_required_callbacks,
        label_proposer_prompt_includes_repo_labels_when_present,
        label_proposer_prompt_falls_back_when_labels_empty,
        summariser_has_required_callbacks,
        all_agents_have_distinct_ids,
        all_system_prompts_non_empty
    ].

init_per_suite(Config) ->
    %% agents call triagebot_config:agent_model()/repo_labels() at
    %% runtime; seed both.
    persistent_term:put({triagebot_config, agent_model}, ~"test-model"),
    persistent_term:put({triagebot_config, repo_labels}, []),
    Config.

end_per_suite(_Config) ->
    persistent_term:erase({triagebot_config, agent_model}),
    persistent_term:erase({triagebot_config, repo_labels}),
    ok.

classifier_uses_repo_context_tool(_Config) ->
    assert_agent_callbacks(triagebot_classifier, classifier, [triagebot_repo_context_tool]).

scoper_uses_repo_context_tool(_Config) ->
    assert_agent_callbacks(triagebot_scoper, scoper, [triagebot_repo_context_tool]).

dup_detector_uses_search_tool(_Config) ->
    assert_agent_callbacks(triagebot_dup_detector, dup_detector, [triagebot_search_tool]).

label_proposer_has_required_callbacks(_Config) ->
    assert_agent_callbacks(triagebot_label_proposer, label_proposer, []).

label_proposer_prompt_includes_repo_labels_when_present(_Config) ->
    Labels = [
        #{name => ~"bug", description => ~"Something is broken", color => ~"d73a4a"},
        #{name => ~"docs", description => ~"", color => ~"0075ca"}
    ],
    persistent_term:put({triagebot_config, repo_labels}, Labels),
    try
        Prompt = triagebot_label_proposer:system_prompt(),
        ?assert(binary:match(Prompt, ~"bug") =/= nomatch),
        ?assert(binary:match(Prompt, ~"Something is broken") =/= nomatch),
        ?assert(binary:match(Prompt, ~"docs") =/= nomatch),
        ?assert(binary:match(Prompt, ~"defined in this repo") =/= nomatch),
        ?assertEqual(nomatch, binary:match(Prompt, ~"could not be fetched"))
    after
        persistent_term:put({triagebot_config, repo_labels}, [])
    end.

label_proposer_prompt_falls_back_when_labels_empty(_Config) ->
    persistent_term:put({triagebot_config, repo_labels}, []),
    Prompt = triagebot_label_proposer:system_prompt(),
    ?assert(binary:match(Prompt, ~"could not be fetched") =/= nomatch),
    ?assert(binary:match(Prompt, ~"base vocabulary") =/= nomatch).

summariser_has_required_callbacks(_Config) ->
    assert_agent_callbacks(triagebot_summariser, summariser, []).

all_agents_have_distinct_ids(_Config) ->
    Ids = [M:id() || M <- ?AGENTS],
    ?assertEqual(length(Ids), length(lists:usort(Ids))).

all_system_prompts_non_empty(_Config) ->
    [?assert(byte_size(M:system_prompt()) > 50) || M <- ?AGENTS].

assert_agent_callbacks(Mod, ExpectedId, ExpectedTools) ->
    ?assertEqual(ExpectedId, Mod:id()),
    ?assert(is_binary(Mod:system_prompt())),
    ?assert(byte_size(Mod:system_prompt()) > 0),
    ?assertEqual(ExpectedTools, Mod:tools()),
    ?assertEqual(~"test-model", Mod:model()).
