-module(triagebot_context_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([
    label_inventory_lists_repo_labels/1,
    label_inventory_falls_back_when_empty/1,
    repo_context_includes_policy_when_present/1,
    repo_context_notes_absent_policy/1,
    repo_context_marks_policy_authoritative/1,
    ticket_surfaces_raw_signals/1,
    ticket_handles_missing_raw/1,
    build_input_combines_context_and_issue/1
]).

all() ->
    [
        label_inventory_lists_repo_labels,
        label_inventory_falls_back_when_empty,
        repo_context_includes_policy_when_present,
        repo_context_notes_absent_policy,
        repo_context_marks_policy_authoritative,
        ticket_surfaces_raw_signals,
        ticket_handles_missing_raw,
        build_input_combines_context_and_issue
    ].

init_per_suite(Config) ->
    persistent_term:put({triagebot_config, triage_policy}, ~""),
    persistent_term:put({triagebot_config, repo_labels}, []),
    Config.

end_per_suite(_Config) ->
    persistent_term:erase({triagebot_config, triage_policy}),
    persistent_term:erase({triagebot_config, repo_labels}),
    ok.

label_inventory_lists_repo_labels(_Config) ->
    Labels = [
        #{name => ~"bug", description => ~"Something is broken", color => ~"d73a4a"},
        #{name => ~"docs", description => ~"", color => ~"0075ca"}
    ],
    Out = triagebot_context:render_label_inventory(Labels),
    ?assert(contains(Out, ~"bug")),
    ?assert(contains(Out, ~"Something is broken")),
    ?assert(contains(Out, ~"docs")),
    ?assert(contains(Out, ~"defined in this repo")),
    ?assertNot(contains(Out, ~"could not be fetched")).

label_inventory_falls_back_when_empty(_Config) ->
    Out = triagebot_context:render_label_inventory([]),
    ?assert(contains(Out, ~"could not be fetched")),
    ?assert(contains(Out, ~"base vocabulary")).

repo_context_includes_policy_when_present(_Config) ->
    Out = triagebot_context:render_repo_context(~"Always escalate security to blocker.", []),
    ?assert(contains(Out, ~"Always escalate security to blocker.")).

repo_context_notes_absent_policy(_Config) ->
    Out = triagebot_context:render_repo_context(~"", []),
    ?assert(contains(Out, ~"No repo-specific triage policy")).

repo_context_marks_policy_authoritative(_Config) ->
    Out = triagebot_context:render_repo_context(~"some policy", []),
    ?assert(contains(Out, ~"authoritative")).

ticket_surfaces_raw_signals(_Config) ->
    Ticket = #{
        id => ~"42",
        title => ~"Crash on startup",
        body => ~"Steps to reproduce ...",
        author => ~"octocat",
        labels => [~"bug"],
        raw => #{
            ~"author_association" => ~"FIRST_TIME_CONTRIBUTOR",
            ~"comments" => 3,
            ~"reactions" => #{~"total_count" => 5, ~"+1" => 4},
            ~"milestone" => #{~"title" => ~"v0.2"},
            ~"assignees" => [#{~"login" => ~"maintainer"}]
        }
    },
    Out = triagebot_context:format_ticket(Ticket),
    ?assert(contains(Out, ~"#42")),
    ?assert(contains(Out, ~"FIRST_TIME_CONTRIBUTOR")),
    ?assert(contains(Out, ~"Comments: 3")),
    ?assert(contains(Out, ~"5 total (4 upvotes)")),
    ?assert(contains(Out, ~"v0.2")),
    ?assert(contains(Out, ~"@maintainer")).

ticket_handles_missing_raw(_Config) ->
    Ticket = #{
        id => ~"7",
        title => ~"Question",
        body => ~"How do I ...",
        author => ~"someone",
        labels => []
    },
    Out = triagebot_context:format_ticket(Ticket),
    ?assert(contains(Out, ~"#7")),
    ?assert(contains(Out, ~"association unknown")),
    ?assert(contains(Out, ~"Comments: 0")),
    ?assert(contains(Out, ~"Milestone: (none)")),
    ?assert(contains(Out, ~"Assignees: (none)")),
    ?assert(contains(Out, ~"Existing labels: (none)")).

build_input_combines_context_and_issue(_Config) ->
    persistent_term:put({triagebot_config, triage_policy}, ~"Escalate security to blocker."),
    persistent_term:put(
        {triagebot_config, repo_labels},
        [#{name => ~"bug", description => ~"", color => ~"d73a4a"}]
    ),
    try
        Ticket = #{
            id => ~"9",
            title => ~"Leak",
            body => ~"secret in logs",
            author => ~"reporter",
            labels => []
        },
        Out = triagebot_context:build_input(Ticket),
        ?assert(contains(Out, ~"Repository triage context")),
        ?assert(contains(Out, ~"Escalate security to blocker.")),
        ?assert(contains(Out, ~"bug")),
        ?assert(contains(Out, ~"#9"))
    after
        persistent_term:put({triagebot_config, triage_policy}, ~""),
        persistent_term:put({triagebot_config, repo_labels}, [])
    end.

contains(Haystack, Needle) ->
    binary:match(Haystack, Needle) =/= nomatch.
