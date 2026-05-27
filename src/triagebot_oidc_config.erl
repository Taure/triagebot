-module(triagebot_oidc_config).
-moduledoc """
OIDC provider config for the triagebot dashboard (nova_auth_oidc behaviour).

Defaults to Google; configure via env:

- `TRIAGEBOT_OIDC_CLIENT_ID` / `TRIAGEBOT_OIDC_CLIENT_SECRET` - OAuth client.
- `TRIAGEBOT_OIDC_ISSUER` - override the issuer (default Google).
- `TRIAGEBOT_BASE_URL` - public base URL (default http://localhost:8080); the
  OAuth redirect URI is `<base>/auth/google/callback`.

"Not everyone can log in" is enforced two ways: the provider only issues
tokens to its users, and `triagebot_dashboard_auth` restricts by email domain
(`TRIAGEBOT_DASHBOARD_ALLOWED_DOMAINS`).
""".

-behaviour(nova_auth_oidc).

-export([config/0]).

config() ->
    #{
        providers => #{
            google => #{
                issuer => env(~"TRIAGEBOT_OIDC_ISSUER", ~"https://accounts.google.com"),
                client_id => env(~"TRIAGEBOT_OIDC_CLIENT_ID", ~""),
                client_secret => env(~"TRIAGEBOT_OIDC_CLIENT_SECRET", ~""),
                scopes => [~"openid", ~"email", ~"profile"]
            }
        },
        base_url => env(~"TRIAGEBOT_BASE_URL", ~"http://localhost:8080"),
        claims_mapping => #{~"sub" => id, ~"email" => email}
    }.

env(Name, Default) ->
    case os:getenv(binary_to_list(Name)) of
        false -> Default;
        "" -> Default;
        Value -> list_to_binary(Value)
    end.
