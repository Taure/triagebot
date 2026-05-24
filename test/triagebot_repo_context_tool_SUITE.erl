-module(triagebot_repo_context_tool_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0]).
-export([
    spec_has_required_fields/1,
    run_rejects_non_binary_path/1,
    run_rejects_missing_path/1
]).

all() ->
    [
        spec_has_required_fields,
        run_rejects_non_binary_path,
        run_rejects_missing_path
    ].

spec_has_required_fields(_Config) ->
    Spec = triagebot_repo_context_tool:spec(),
    ?assertEqual(~"read_repo_file", maps:get(name, Spec)),
    ?assert(is_binary(maps:get(description, Spec))),
    Schema = maps:get(input_schema, Spec),
    ?assertEqual(~"object", maps:get(type, Schema)),
    ?assert(maps:is_key(path, maps:get(properties, Schema))),
    ?assertEqual([~"path"], maps:get(required, Schema)).

run_rejects_non_binary_path(_Config) ->
    ?assertEqual(
        {error, invalid_input},
        triagebot_repo_context_tool:run(#{~"path" => "not-a-binary"})
    ).

run_rejects_missing_path(_Config) ->
    ?assertEqual(
        {error, invalid_input},
        triagebot_repo_context_tool:run(#{})
    ).
