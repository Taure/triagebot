-module(triagebot_search_tool_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0]).
-export([
    spec_has_required_fields/1,
    run_rejects_non_binary_query/1,
    run_rejects_missing_query/1
]).

all() ->
    [
        spec_has_required_fields,
        run_rejects_non_binary_query,
        run_rejects_missing_query
    ].

spec_has_required_fields(_Config) ->
    Spec = triagebot_search_tool:spec(),
    ?assertEqual(~"search_issues", maps:get(name, Spec)),
    ?assert(is_binary(maps:get(description, Spec))),
    Schema = maps:get(input_schema, Spec),
    ?assertEqual(~"object", maps:get(type, Schema)),
    ?assert(maps:is_key(query, maps:get(properties, Schema))),
    ?assertEqual([~"query"], maps:get(required, Schema)).

run_rejects_non_binary_query(_Config) ->
    ?assertEqual(
        {error, invalid_input},
        triagebot_search_tool:run(#{~"query" => not_a_binary})
    ).

run_rejects_missing_query(_Config) ->
    ?assertEqual(
        {error, invalid_input},
        triagebot_search_tool:run(#{})
    ).
