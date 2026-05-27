-module(triagebot_dashboard_auth_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_testcase/2, end_per_testcase/2]).
-export([
    denied_when_unconfigured/1,
    challenges_without_credentials/1,
    challenge_sets_www_authenticate/1,
    accepts_correct_credentials/1,
    rejects_wrong_password/1,
    rejects_wrong_username/1
]).

-define(USER, "conductor").
-define(PASS, "a-very-long-hard-passphrase").

all() ->
    [
        denied_when_unconfigured,
        challenges_without_credentials,
        challenge_sets_www_authenticate,
        accepts_correct_credentials,
        rejects_wrong_password,
        rejects_wrong_username
    ].

init_per_testcase(denied_when_unconfigured, Config) ->
    clear_env(),
    Config;
init_per_testcase(_Case, Config) ->
    os:putenv("TRIAGEBOT_DASHBOARD_USER", ?USER),
    os:putenv("TRIAGEBOT_DASHBOARD_PASSWORD", ?PASS),
    Config.

end_per_testcase(_Case, _Config) ->
    clear_env(),
    ok.

clear_env() ->
    os:unsetenv("TRIAGEBOT_DASHBOARD_USER"),
    os:unsetenv("TRIAGEBOT_DASHBOARD_PASSWORD").

denied_when_unconfigured(_Config) ->
    ?assertMatch({false, 503, _, _}, triagebot_dashboard_auth:check(req(undefined))).

challenges_without_credentials(_Config) ->
    ?assertMatch({false, 401, _, _}, triagebot_dashboard_auth:check(req(undefined))).

challenge_sets_www_authenticate(_Config) ->
    {false, 401, Headers, _} = triagebot_dashboard_auth:check(req(undefined)),
    ?assert(maps:is_key(~"www-authenticate", Headers)).

accepts_correct_credentials(_Config) ->
    ?assertMatch(
        {true, #{user := <<"conductor">>}},
        triagebot_dashboard_auth:check(req({?USER, ?PASS}))
    ).

rejects_wrong_password(_Config) ->
    ?assertMatch(
        {false, 401, _, _},
        triagebot_dashboard_auth:check(req({?USER, "wrong"}))
    ).

rejects_wrong_username(_Config) ->
    ?assertMatch(
        {false, 401, _, _},
        triagebot_dashboard_auth:check(req({"intruder", ?PASS}))
    ).

req(undefined) ->
    #{headers => #{}};
req({User, Pass}) ->
    Cred = base64:encode(iolist_to_binary([User, ":", Pass])),
    #{headers => #{~"authorization" => <<"Basic ", Cred/binary>>}}.
