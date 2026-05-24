-module(triagebot_webhook_controller).
-moduledoc """
Nova controller for GitHub webhook deliveries.

Reads the raw body (needed for HMAC), verifies the signature against the
configured shared secret, parses the event, and hands off to
`triagebot_runner` for async processing.

Returns:
- 202 Accepted on a verified, supported event.
- 200 OK on a verified-but-unsupported event (we won't process it but
  GitHub shouldn't retry).
- 401 Unauthorized if the signature doesn't match.
- 400 Bad Request on malformed payloads.

Nova's `handle_status` does not accept a trailing `Req` in 3-tuple form;
that slot is `ExtraHeaders :: map()`. We use the bare `{status, Code}`
form to let Nova render with its own Req.
""".

-include_lib("kernel/include/logger.hrl").

-export([github_event/1]).

github_event(Req) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req),
    Sig = cowboy_req:header(~"x-hub-signature-256", Req1, ~""),
    EventType = cowboy_req:header(~"x-github-event", Req1, ~""),
    Delivery = cowboy_req:header(~"x-github-delivery", Req1, ~""),
    Secret = triagebot_config:webhook_secret(),
    case gakudan_tickets_github:verify_signature(Secret, Sig, Body) of
        false ->
            ?LOG_WARNING(#{event => webhook_signature_invalid, delivery => Delivery}),
            {status, 401};
        true ->
            handle_verified(EventType, Body, Delivery)
    end.

handle_verified(EventType, Body, Delivery) ->
    case gakudan_tickets_github:parse_webhook(EventType, Body) of
        {ok, {Event, Ticket}} ->
            ?LOG_INFO(#{
                event => webhook_received,
                github_event => EventType,
                action => Event,
                delivery => Delivery,
                ticket_id => maps:get(id, Ticket)
            }),
            ok = triagebot_runner:dispatch(Event, Ticket),
            {status, 202};
        {error, {unsupported_event, _}} ->
            ?LOG_INFO(#{
                event => webhook_unsupported,
                github_event => EventType,
                delivery => Delivery
            }),
            {status, 200};
        {error, Reason} ->
            ?LOG_WARNING(#{
                event => webhook_bad_payload,
                reason => Reason,
                delivery => Delivery
            }),
            {status, 400}
    end.
