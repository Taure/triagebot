-module(triagebot_context).
-moduledoc """
Builds the run input sent to the gakudan triage pipeline.

The input is a single message every agent reads: a shared
repository-context preamble (the triage policy + the repo's label
taxonomy) followed by the issue itself, enriched with the high-signal
fields GitHub puts in the raw issue payload - contributor association,
reactions, comment count, milestone, and assignees.

Keeping the policy and label vocabulary here, in the shared input, means
they live in one place rather than being duplicated across every agent's
system prompt.
""".

-export([build_input/1, render_repo_context/2, render_label_inventory/1, format_ticket/1]).

-spec build_input(gakudan_tickets:ticket()) -> binary().
build_input(Ticket) ->
    iolist_to_binary([
        render_repo_context(triagebot_config:triage_policy(), triagebot_config:repo_labels()),
        ~"\n",
        format_ticket(Ticket)
    ]).

-spec render_repo_context(binary(), [map()]) -> binary().
render_repo_context(Policy, Labels) ->
    iolist_to_binary([
        ~"=== Repository triage context ===\n\n",
        render_policy(Policy),
        ~"\n\n",
        render_label_inventory(Labels)
    ]).

-spec format_ticket(gakudan_tickets:ticket()) -> binary().
format_ticket(Ticket) ->
    Id = maps:get(id, Ticket),
    Title = maps:get(title, Ticket, ~""),
    Body = maps:get(body, Ticket, ~""),
    Author = maps:get(author, Ticket, ~""),
    Labels = maps:get(labels, Ticket, []),
    Raw = maps:get(raw, Ticket, #{}),
    iolist_to_binary([
        ~"=== Issue ===\n",
        ~"GitHub issue #",
        Id,
        ~": \"",
        Title,
        ~"\"\n",
        ~"Opened by @",
        Author,
        ~" (",
        author_association(Raw),
        ~")\n",
        ~"Existing labels: ",
        format_label_list(Labels),
        ~"\n",
        ~"Reactions: ",
        reactions(Raw),
        ~"\n",
        ~"Comments: ",
        integer_to_binary(int_field(Raw, ~"comments", 0)),
        ~"\n",
        ~"Milestone: ",
        milestone(Raw),
        ~"\n",
        ~"Assignees: ",
        assignees(Raw),
        ~"\n\n---\n",
        Body,
        ~"\n---\n"
    ]).

%% --- internal ---

render_policy(<<>>) ->
    ~"""
    ## Triage policy

    No repo-specific triage policy is configured; use the default
    judgement described in your instructions.
    """;
render_policy(Policy) ->
    iolist_to_binary([
        ~"## Triage policy (authoritative - follow it wherever it conflicts with your default instructions)\n\n",
        Policy
    ]).

render_label_inventory([]) ->
    ~"""
    ## Labels

    The repo's label taxonomy could not be fetched. Fall back to this
    base vocabulary, and only propose labels you are confident the repo
    already defines:

      bug, feature, docs, question, discussion, duplicate-suspect,
      cosmetic, minor, major, blocker,
      self-contained, cross-cutting,
      good-first-issue, needs-info, claude-try
    """;
render_label_inventory(Labels) ->
    Lines = [render_label(L) || L <- Labels],
    iolist_to_binary([
        ~"## Labels defined in this repo (propose labels only from this list)\n\n",
        lists:join(~"\n", Lines)
    ]).

render_label(#{name := N, description := ~""}) ->
    [~"  - `", N, ~"`"];
render_label(#{name := N, description := D}) ->
    [~"  - `", N, ~"`: ", D].

format_label_list([]) -> ~"(none)";
format_label_list(Labels) -> iolist_to_binary(lists:join(~", ", Labels)).

author_association(Raw) ->
    case maps:get(~"author_association", Raw, ~"") of
        A when is_binary(A), A =/= ~"" -> A;
        _ -> ~"association unknown"
    end.

reactions(Raw) ->
    case maps:get(~"reactions", Raw, undefined) of
        R when is_map(R) ->
            Total = int_field(R, ~"total_count", 0),
            Up = int_field(R, ~"+1", 0),
            iolist_to_binary([
                integer_to_binary(Total),
                ~" total (",
                integer_to_binary(Up),
                ~" upvotes)"
            ]);
        _ ->
            ~"0"
    end.

milestone(Raw) ->
    case maps:get(~"milestone", Raw, null) of
        M when is_map(M) ->
            case maps:get(~"title", M, ~"") of
                T when is_binary(T), T =/= ~"" -> T;
                _ -> ~"(untitled)"
            end;
        _ ->
            ~"(none)"
    end.

assignees(Raw) ->
    case maps:get(~"assignees", Raw, []) of
        As when is_list(As), As =/= [] ->
            Logins = [maps:get(~"login", A, ~"?") || A <- As, is_map(A)],
            iolist_to_binary(lists:join(~", ", [[~"@", L] || L <- Logins]));
        _ ->
            ~"(none)"
    end.

int_field(Map, Key, Default) ->
    case maps:get(Key, Map, Default) of
        I when is_integer(I) -> I;
        _ -> Default
    end.
