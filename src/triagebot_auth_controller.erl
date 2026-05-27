-module(triagebot_auth_controller).
-moduledoc """
Adapter in front of `nova_auth_oidc_controller`.

This Nova build keys route bindings by the path-segment binary (`~"provider"`),
but `nova_auth_oidc_controller` pattern-matches an atom `provider` binding and
reads `auth_mod` from the request. We normalise the binding to an atom and pin
the OIDC config module, then delegate. Remove once nova_auth_oidc accepts
binary-keyed bindings upstream.
""".

-export([login/1, callback/1, adapt/1]).

login(Req) ->
    nova_auth_oidc_controller:login(adapt(Req)).

callback(Req) ->
    nova_auth_oidc_controller:callback(adapt(Req)).

adapt(Req) ->
    Bindings = maps:get(bindings, Req, #{}),
    ProviderBin = maps:get(~"provider", Bindings, ~"google"),
    Req#{bindings => Bindings#{provider => ProviderBin}, auth_mod => triagebot_oidc_config}.
