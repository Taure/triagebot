-module(triagebot_health_controller).
-moduledoc false.

-export([status/1]).

status(_Req) ->
    {json, #{status => ok, app => triagebot}}.
