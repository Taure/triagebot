-module(triagebot_agents_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([
    classifier_has_required_callbacks/1,
    scoper_has_required_callbacks/1,
    dup_detector_uses_search_tool/1,
    label_proposer_has_required_callbacks/1,
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
        classifier_has_required_callbacks,
        scoper_has_required_callbacks,
        dup_detector_uses_search_tool,
        label_proposer_has_required_callbacks,
        summariser_has_required_callbacks,
        all_agents_have_distinct_ids,
        all_system_prompts_non_empty
    ].

init_per_suite(Config) ->
    %% agents call triagebot_config:agent_model() at runtime; seed it.
    persistent_term:put({triagebot_config, agent_model}, ~"test-model"),
    Config.

end_per_suite(_Config) ->
    persistent_term:erase({triagebot_config, agent_model}),
    ok.

classifier_has_required_callbacks(_Config) ->
    assert_agent_callbacks(triagebot_classifier, classifier, []).

scoper_has_required_callbacks(_Config) ->
    assert_agent_callbacks(triagebot_scoper, scoper, []).

dup_detector_uses_search_tool(_Config) ->
    assert_agent_callbacks(triagebot_dup_detector, dup_detector, [triagebot_search_tool]).

label_proposer_has_required_callbacks(_Config) ->
    assert_agent_callbacks(triagebot_label_proposer, label_proposer, []).

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
