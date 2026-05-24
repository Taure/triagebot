-module(triagebot_app).
-moduledoc false.

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    ok = triagebot_config:setup(),
    maybe_start_metrics_listener(),
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
