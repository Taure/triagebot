-module(triagebot_config).
-moduledoc """
Runtime configuration for triagebot, sourced from env vars.

Reads everything from the environment at startup, stashes the resolved
GitHub source_ref in `persistent_term` so the search tool (which runs
inside a turn-worker process spawned by gakudan) can read it without a
GenServer round-trip.

Required env vars:
- TRIAGEBOT_WEBHOOK_SECRET    GitHub webhook shared secret (HMAC)
- TRIAGEBOT_REPO_OWNER        e.g. "Taure"
- TRIAGEBOT_REPO_NAME         e.g. "gakudan"

GitHub auth (one of):
- TRIAGEBOT_GITHUB_TOKEN                            (PAT mode)
- TRIAGEBOT_GITHUB_APP_ID + TRIAGEBOT_GITHUB_APP_PRIVATE_KEY_PEM
    + TRIAGEBOT_GITHUB_INSTALLATION_ID              (App mode)

LLM backend (one of):
- ANTHROPIC_API_KEY
- GEMINI_API_KEY

Optional:
- TRIAGEBOT_PORT              Nova listen port (default 8080)
- TRIAGEBOT_METRICS_PORT      Prometheus /metrics port (default 9568,
                              set to "" to disable)
- TRIAGEBOT_AGENT_MODEL       Override per-agent model (default
                              claude-sonnet-4-6 for Anthropic,
                              gemini-2.5-flash for Gemini)
""".

-export([setup/0]).
-export([webhook_secret/0, github_source/0, llm_backend_spec/0, agent_model/0]).
-export([port/0, metrics_port/0]).

-define(SOURCE_KEY, {?MODULE, github_source}).
-define(SECRET_KEY, {?MODULE, webhook_secret}).
-define(LLM_KEY, {?MODULE, llm_backend_spec}).
-define(MODEL_KEY, {?MODULE, agent_model}).

-spec setup() -> ok.
setup() ->
    persistent_term:put(?SECRET_KEY, must_env("TRIAGEBOT_WEBHOOK_SECRET")),
    persistent_term:put(?SOURCE_KEY, resolve_github_source()),
    {LlmSpec, Model} = resolve_llm(),
    persistent_term:put(?LLM_KEY, LlmSpec),
    persistent_term:put(?MODEL_KEY, Model),
    ok.

-spec webhook_secret() -> binary().
webhook_secret() ->
    persistent_term:get(?SECRET_KEY).

-spec github_source() -> map().
github_source() ->
    persistent_term:get(?SOURCE_KEY).

-spec llm_backend_spec() -> {module(), map()}.
llm_backend_spec() ->
    persistent_term:get(?LLM_KEY).

-spec agent_model() -> binary().
agent_model() ->
    persistent_term:get(?MODEL_KEY).

-spec port() -> inet:port_number().
port() ->
    case os:getenv("TRIAGEBOT_PORT") of
        false -> 8080;
        "" -> 8080;
        V -> list_to_integer(V)
    end.

-spec metrics_port() -> inet:port_number() | undefined.
metrics_port() ->
    case os:getenv("TRIAGEBOT_METRICS_PORT") of
        false -> 9568;
        "" -> undefined;
        V -> list_to_integer(V)
    end.

%% --- internal ---

resolve_github_source() ->
    Owner = list_to_binary(must_env("TRIAGEBOT_REPO_OWNER")),
    Repo = list_to_binary(must_env("TRIAGEBOT_REPO_NAME")),
    Auth = resolve_github_auth(),
    gakudan_tickets_github:source(maps:merge(#{owner => Owner, repo => Repo}, Auth)).

resolve_github_auth() ->
    case os:getenv("TRIAGEBOT_GITHUB_TOKEN") of
        Token when is_list(Token), Token =/= "" ->
            #{token => list_to_binary(Token)};
        _ ->
            #{
                app => #{
                    app_id => must_int_env("TRIAGEBOT_GITHUB_APP_ID"),
                    private_key_pem =>
                        list_to_binary(must_env("TRIAGEBOT_GITHUB_APP_PRIVATE_KEY_PEM")),
                    installation_id => must_int_env("TRIAGEBOT_GITHUB_INSTALLATION_ID")
                }
            }
    end.

resolve_llm() ->
    case os:getenv("ANTHROPIC_API_KEY") of
        K when is_list(K), K =/= "" ->
            {
                {gakudan_llm_anthropic, #{api_key => list_to_binary(K)}},
                resolve_model(~"claude-sonnet-4-6")
            };
        _ ->
            case os:getenv("GEMINI_API_KEY") of
                K when is_list(K), K =/= "" ->
                    {
                        {gakudan_llm_gemini, #{api_key => list_to_binary(K)}},
                        resolve_model(~"gemini-2.5-flash")
                    };
                _ ->
                    error({missing_env, ["ANTHROPIC_API_KEY", "GEMINI_API_KEY"]})
            end
    end.

resolve_model(Default) ->
    case os:getenv("TRIAGEBOT_AGENT_MODEL") of
        false -> Default;
        "" -> Default;
        V -> list_to_binary(V)
    end.

must_env(Name) ->
    case os:getenv(Name) of
        V when is_list(V), V =/= "" -> V;
        _ -> error({missing_env, Name})
    end.

must_int_env(Name) ->
    list_to_integer(must_env(Name)).
