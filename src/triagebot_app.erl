-module(triagebot_app).
-moduledoc false.

-behaviour(application).

-include_lib("kernel/include/logger.hrl").

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    ok = triagebot_config:setup(),
    maybe_start_metrics_listener(),
    ok = maybe_start_oidc(),
    triagebot_sup:start_link().

stop(_State) ->
    ok.

maybe_start_metrics_listener() ->
    case triagebot_config:metrics_port() of
        undefined ->
            ok;
        Port when is_integer(Port) ->
            {ok, _} = gakudan_metrics:start_listener(Port),
            ok
    end.

maybe_start_oidc() ->
    case os:getenv("TRIAGEBOT_OIDC_CLIENT_ID") of
        Empty when Empty =:= false; Empty =:= "" ->
            ?LOG_WARNING(#{
                event => dashboard_oidc_disabled,
                detail =>
                    ~"TRIAGEBOT_OIDC_CLIENT_ID not set; the live dashboard is mounted but login will not work"
            }),
            ok;
        _ ->
            _ = nova_auth_oidc:ensure_providers(triagebot_oidc_config),
            ok
    end.
