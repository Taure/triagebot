-module(triagebot_router).
-moduledoc false.

-behaviour(nova_router).

-export([routes/1]).

routes(_Environment) ->
    [
        #{
            prefix => "",
            security => false,
            routes => [
                {"/webhook/github", fun triagebot_webhook_controller:github_event/1, #{
                    methods => [post]
                }},
                {"/health", fun triagebot_health_controller:status/1, #{methods => [get]}}
            ]
        }
    ].
