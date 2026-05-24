-module(triagebot_repo_context_tool).
-moduledoc """
gakudan tool that fetches a file from the configured GitHub repo,
giving the triage agents a way to ground themselves in repo-specific
context (`CLAUDE.md`, `README.md`, `CONTRIBUTING.md`, the file an
issue links to, etc.).

The active GitHub source_ref is read from `triagebot_config`
(persistent_term) because tools run inside a turn-worker process with
no parameter for per-run context.

File contents are truncated to `?MAX_BYTES` to keep prompt size
bounded; the LLM sees a clear suffix when truncation happened.
""".

-behaviour(gakudan_tool).

-export([spec/0, run/1]).

-define(MAX_BYTES, 16_000).

spec() ->
    #{
        name => ~"read_repo_file",
        description =>
            ~"""
            Read a file from the configured GitHub repository's default
            branch. Use this to ground yourself in the repo before
            classifying or scoring an issue - for example fetch
            CLAUDE.md, README.md, CONTRIBUTING.md, or the file an
            issue links to. Returns the file's raw text contents
            (truncated to 16 KB).
            """,
        input_schema => #{
            type => ~"object",
            properties => #{
                path => #{
                    type => ~"string",
                    description =>
                        ~"Repo-relative file path, e.g. \"README.md\" or \"src/foo.erl\"."
                }
            },
            required => [~"path"]
        }
    }.

run(#{~"path" := Path}) when is_binary(Path) ->
    Source = triagebot_config:github_source(),
    case gakudan_tickets_github:get_file(Source, Path) of
        {ok, Bytes} -> {ok, truncate(Bytes)};
        {error, not_found} -> {ok, ~"File not found in repo."};
        {error, is_directory} -> {ok, ~"That path is a directory, not a file."};
        {error, too_large} -> {ok, ~"File is too large to inline (>1 MB)."};
        {error, Reason} -> {error, Reason}
    end;
run(_Other) ->
    {error, invalid_input}.

truncate(Bytes) when byte_size(Bytes) =< ?MAX_BYTES ->
    Bytes;
truncate(Bytes) ->
    Head = binary:part(Bytes, 0, ?MAX_BYTES),
    iolist_to_binary([
        Head,
        ~"\n\n[... truncated, file is ",
        integer_to_binary(byte_size(Bytes)),
        ~" bytes total]"
    ]).
