-module(triagebot_sup).
-moduledoc false.

-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    %% Triagebot has no long-lived workers in v0.1; webhook-triggered
    %% triage runs spawn ad-hoc Erlang processes managed by gakudan's
    %% own per-run supervision trees.
    {ok, {SupFlags, []}}.
