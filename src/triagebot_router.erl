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
                {"/health", fun triagebot_health_controller:status/1, #{methods => [get]}},
                {"/assets/[...]", liveboard_assets_dir()}
            ]
        },
        #{
            prefix => "",
            security => fun triagebot_dashboard_auth:check/1,
            routes => [
                {"/", fun gakudan_liveboard_page_controller:index/1, #{methods => [get]}},
                {"/runs/:run_id", fun gakudan_liveboard_page_controller:show/1, #{methods => [get]}},
                {"/sse/runs/:run_id", fun gakudan_liveboard_sse:stream/1, #{methods => [get]}},
                {"/runs/:run_id/interrupt", fun gakudan_liveboard_action_controller:interrupt/1, #{
                    methods => [post]
                }},
                {"/runs/:run_id/resume", fun gakudan_liveboard_action_controller:resume/1, #{
                    methods => [post]
                }},
                {"/runs/:run_id/cancel", fun gakudan_liveboard_action_controller:cancel/1, #{
                    methods => [post]
                }}
            ]
        }
    ].

liveboard_assets_dir() ->
    filename:join(code:priv_dir(gakudan_liveboard), "static/assets").
