-module(triagebot_dashboard_auth).
-moduledoc """
HTTP Basic auth gate for the triagebot live dashboard.

Credentials come from `TRIAGEBOT_DASHBOARD_USER` / `TRIAGEBOT_DASHBOARD_PASSWORD`.

Closed by default: if either is unset the dashboard denies everything (503), so
it is never accidentally exposed. The username and password are compared in
constant time. Gates both the view routes and the HITL controls.
""".

-export([check/1]).

-spec check(cowboy_req:req()) ->
    {true, map()} | {false, 401 | 503, map(), binary()}.
check(Req) ->
    case credentials() of
        {ok, User, Pass} -> verify(Req, User, Pass);
        error -> unconfigured()
    end.

credentials() ->
    case {os:getenv("TRIAGEBOT_DASHBOARD_USER"), os:getenv("TRIAGEBOT_DASHBOARD_PASSWORD")} of
        {User, Pass} when is_list(User), is_list(Pass), User =/= "", Pass =/= "" ->
            {ok, list_to_binary(User), list_to_binary(Pass)};
        _ ->
            error
    end.

verify(Req, User, Pass) ->
    case cowboy_req:parse_header(~"authorization", Req) of
        {basic, GivenUser, GivenPass} ->
            UserOk = secure_equal(GivenUser, User),
            PassOk = secure_equal(GivenPass, Pass),
            case UserOk andalso PassOk of
                true -> {true, #{user => User}};
                false -> challenge()
            end;
        _ ->
            challenge()
    end.

%% Constant-time comparison: hash both sides to a fixed length first so
%% crypto:hash_equals/2 never leaks length and never raises on size mismatch.
secure_equal(A, B) ->
    crypto:hash_equals(crypto:hash(sha256, A), crypto:hash(sha256, B)).

challenge() ->
    {false, 401,
        #{
            ~"www-authenticate" => ~"Basic realm=\"triagebot dashboard\", charset=\"UTF-8\"",
            ~"content-type" => ~"text/plain; charset=utf-8"
        },
        ~"Authentication required"}.

unconfigured() ->
    {false, 503, #{~"content-type" => ~"text/plain; charset=utf-8"},
        ~"Dashboard auth not configured (set TRIAGEBOT_DASHBOARD_USER and _PASSWORD)"}.
