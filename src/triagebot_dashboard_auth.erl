-module(triagebot_dashboard_auth).
-moduledoc """
Route security for the triagebot live dashboard.

Gates the `gakudan_liveboard` pages behind an authenticated session and an
email-domain allowlist, so "not everyone can log in":

- no session -> 302 redirect to the OIDC login,
- authenticated but email domain not allowed -> 403,
- authenticated and allowed -> `{true, Actor}`.

The allowlist is `TRIAGEBOT_DASHBOARD_ALLOWED_DOMAINS` (comma-separated, e.g.
`taure.se,example.com`). Empty/unset allows any authenticated user, which is
the right default for a single-org Google Workspace where the OIDC provider is
already the gate.
""".

-export([check/1, authorize/1]).

-spec check(cowboy_req:req()) ->
    {true, nova_auth:actor()} | {false, integer(), map(), binary()}.
check(Req) ->
    authorize(nova_auth_actor:fetch(Req)).

-spec authorize({ok, nova_auth:actor()} | {error, not_found}) ->
    {true, nova_auth:actor()} | {false, integer(), map(), binary()}.
authorize({ok, Actor}) ->
    case allowed(Actor) of
        true -> {true, Actor};
        false -> forbidden()
    end;
authorize({error, not_found}) ->
    login_redirect().

allowed(#{email := Email}) when is_binary(Email) ->
    case allowed_domains() of
        [] -> true;
        Domains -> lists:member(domain_of(Email), Domains)
    end;
allowed(_Actor) ->
    allowed_domains() =:= [].

domain_of(Email) ->
    case binary:split(Email, ~"@") of
        [_, Domain] -> string:lowercase(Domain);
        _ -> ~""
    end.

allowed_domains() ->
    case os:getenv("TRIAGEBOT_DASHBOARD_ALLOWED_DOMAINS") of
        false ->
            [];
        "" ->
            [];
        Raw ->
            [
                string:lowercase(list_to_binary(string:trim(D)))
             || D <- string:split(Raw, ",", all), D =/= ""
            ]
    end.

login_redirect() ->
    {false, 302, #{~"location" => login_url()}, ~""}.

login_url() ->
    case os:getenv("TRIAGEBOT_OIDC_PROVIDER") of
        false -> ~"/auth/google/login";
        "" -> ~"/auth/google/login";
        Provider -> iolist_to_binary([~"/auth/", Provider, ~"/login"])
    end.

forbidden() ->
    Body =
        ~"""
        <!doctype html><meta charset="utf-8"><title>Not allowed</title>
        <body style="font-family:system-ui;background:#14110d;color:#e8dfce;display:grid;place-items:center;height:100vh;margin:0">
        <main style="text-align:center"><h1 style="font-weight:400">Not allowed</h1>
        <p>Your account is not permitted on this dashboard.</p></main>
        """,
    {false, 403, #{~"content-type" => ~"text/html; charset=utf-8"}, Body}.
