-module(triagebot_dashboard_auth_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_testcase/2, end_per_testcase/2]).
-export([
    unauthenticated_redirects_to_login/1,
    login_url_honours_provider_env/1,
    no_allowlist_allows_any_authenticated/1,
    allowlist_permits_listed_domain/1,
    allowlist_is_case_insensitive/1,
    allowlist_rejects_other_domain/1,
    allowlist_rejects_actor_without_email/1,
    adapt_normalises_binary_binding/1,
    adapt_defaults_provider_to_google/1,
    oidc_config_exposes_google_provider/1
]).

all() ->
    [
        unauthenticated_redirects_to_login,
        login_url_honours_provider_env,
        no_allowlist_allows_any_authenticated,
        allowlist_permits_listed_domain,
        allowlist_is_case_insensitive,
        allowlist_rejects_other_domain,
        allowlist_rejects_actor_without_email,
        adapt_normalises_binary_binding,
        adapt_defaults_provider_to_google,
        oidc_config_exposes_google_provider
    ].

init_per_testcase(_Case, Config) ->
    clear_env(),
    Config.

end_per_testcase(_Case, _Config) ->
    clear_env(),
    ok.

clear_env() ->
    os:unsetenv("TRIAGEBOT_DASHBOARD_ALLOWED_DOMAINS"),
    os:unsetenv("TRIAGEBOT_OIDC_PROVIDER"),
    os:unsetenv("TRIAGEBOT_OIDC_CLIENT_ID").

unauthenticated_redirects_to_login(_Config) ->
    ?assertEqual(
        {false, 302, #{~"location" => ~"/auth/google/login"}, ~""},
        triagebot_dashboard_auth:authorize({error, not_found})
    ).

login_url_honours_provider_env(_Config) ->
    os:putenv("TRIAGEBOT_OIDC_PROVIDER", "authentik"),
    {false, 302, Headers, _} = triagebot_dashboard_auth:authorize({error, not_found}),
    ?assertEqual(~"/auth/authentik/login", maps:get(~"location", Headers)).

no_allowlist_allows_any_authenticated(_Config) ->
    Actor = #{email => ~"anyone@whatever.com"},
    ?assertEqual({true, Actor}, triagebot_dashboard_auth:authorize({ok, Actor})).

allowlist_permits_listed_domain(_Config) ->
    os:putenv("TRIAGEBOT_DASHBOARD_ALLOWED_DOMAINS", "taure.se, example.com"),
    Actor = #{email => ~"daniel@taure.se"},
    ?assertEqual({true, Actor}, triagebot_dashboard_auth:authorize({ok, Actor})).

allowlist_is_case_insensitive(_Config) ->
    os:putenv("TRIAGEBOT_DASHBOARD_ALLOWED_DOMAINS", "Taure.SE"),
    Actor = #{email => ~"Daniel@TAURE.se"},
    ?assertEqual({true, Actor}, triagebot_dashboard_auth:authorize({ok, Actor})).

allowlist_rejects_other_domain(_Config) ->
    os:putenv("TRIAGEBOT_DASHBOARD_ALLOWED_DOMAINS", "taure.se"),
    ?assertMatch(
        {false, 403, _, _},
        triagebot_dashboard_auth:authorize({ok, #{email => ~"intruder@evil.com"}})
    ).

allowlist_rejects_actor_without_email(_Config) ->
    os:putenv("TRIAGEBOT_DASHBOARD_ALLOWED_DOMAINS", "taure.se"),
    ?assertMatch(
        {false, 403, _, _},
        triagebot_dashboard_auth:authorize({ok, #{id => ~"u1"}})
    ).

adapt_normalises_binary_binding(_Config) ->
    Adapted = triagebot_auth_controller:adapt(#{bindings => #{~"provider" => ~"authentik"}}),
    ?assertEqual(~"authentik", maps:get(provider, maps:get(bindings, Adapted))),
    ?assertEqual(triagebot_oidc_config, maps:get(auth_mod, Adapted)).

adapt_defaults_provider_to_google(_Config) ->
    Adapted = triagebot_auth_controller:adapt(#{bindings => #{}}),
    ?assertEqual(~"google", maps:get(provider, maps:get(bindings, Adapted))).

oidc_config_exposes_google_provider(_Config) ->
    os:putenv("TRIAGEBOT_OIDC_CLIENT_ID", "abc.apps.googleusercontent.com"),
    Cfg = triagebot_oidc_config:config(),
    Google = maps:get(google, maps:get(providers, Cfg)),
    ?assertEqual(~"abc.apps.googleusercontent.com", maps:get(client_id, Google)),
    ?assertEqual(#{~"sub" => id, ~"email" => email}, maps:get(claims_mapping, Cfg)).
