#!/usr/bin/env bash
# Opens pull requests on crmne/ruby_llm from branches on kieranklaassen/ruby_llm.
# Usage: open-prs.sh high|medium|low      Safe to rerun: skips branches that already have a pull request.
set -u
want="${1:?high, medium or low}"
open_pr() {
  [ "$1" = "$want" ] || return 0
  n=$(gh pr list --repo crmne/ruby_llm --state all --head "$2" --author kieranklaassen --json number --jq '.[0].number')
  if [ -n "$n" ]; then echo "exists #$n $2"; cat >/dev/null; return 0; fi
  f=$(mktemp); cat > "$f"
  gh pr create --repo crmne/ruby_llm --base main --head "kieranklaassen:$2" --title "$3" --body-file "$f" || echo "FAILED $2"
  rm -f "$f"; sleep 20
}
open_pr high claude/fix-end-the-tool-call-of-a-failed-mcp-task 'End the tool call of a failed MCP task' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

When an MCP background task fails, its chat gets stuck. `complete` raises, as the guide says, but the tool call stays pending, so every later `complete` raises the same error and every `ask` is refused. The only way out is to cancel.

```ruby
chat.with_mcp(reports).ask("Render the report") # the call becomes a task
# The server reports the task as failed.

chat.complete # raises RubyLLM::MCP::Error: Renderer crashed, as documented
chat.complete
# main: raises RubyLLM::MCP::Error again, forever
# expected: the model reads that the call failed, and the chat goes on
```

The first `complete` still raises. It now saves how the task ended with the tool call, so the next `complete` gives the model the failure as a tool error, like any other MCP call the server fails. A check that fails while the task may still be running keeps the call pending, as before.

Limit: a task the server no longer knows still raises each time, since its answer does not say how the task ended. `cancel` drops it.

If you would rather hand the model the failure on the first `complete`, that is a smaller change, but it changes the documented raise.

Tests: new examples in `chat_with_mcp_spec.rb` and `acts_as_mcp_tasks_spec.rb` (from another process) fail on main. The MCP, outage, and task specs pass.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr high claude/fix-escape-nul-in-chat-content 'Escape NUL in stored messages and tool calls' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

On PostgreSQL, one NUL byte in a reply, a tool result or a tool argument fails the turn after the provider billed it.

```ruby
class ReadLog < RubyLLM::Tool
  description "Reads a log"

  def execute
    "bin\u0000data"
  end
end

chat.with_tools(ReadLog).ask("Read the log")
# main, PostgreSQL: ArgumentError: string contains null byte
# main, SQLite:     answers
# expected:         answers on both
```

A NUL in well-formed tool arguments raises `PG::UntranslatableCharacter` the same way. The gem already escapes malformed arguments with `without_nul`. That method now covers every message attribute, tool call attribute and stored MCP result. The run in progress still sends the model the original text; a reload reads the escape.

System prompts, queued messages and text converted from files are stored as before.

I ran the tool result, argument and reply cases on PostgreSQL 16 by script; the specs run on SQLite and check the stored text. Tests: the chat methods, MCP and usage ledger specs; no live requests.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr high claude/fix-fail-vertexai-rows-empty-response 'Fail Vertex AI batch rows with an empty response' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A failed row of a Vertex AI batch comes back as a successful empty answer, and its error is dropped.

```ruby
# one row of the batch output
# { "status": "Bad Request", "response": {}, "request": { ... } }

batch.results
# main:     an empty message for that row
# expected: no message, the row failed, and a warning with "Bad Request"
```

A failed row carries its error in `status` beside an empty `response`, and an empty Hash is truthy in Ruby. An empty response now counts as none. [The format is documented for Gemini rows](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/multimodal/batch-prediction-from-cloud-storage); the parsers for Claude and for other models on Vertex AI had the same check and now share the fix. This rests on the documentation and was not exercised live.

Tests: `ruby_llm/providers/vertexai/anthropic/batches_spec.rb`, `ruby_llm/providers/vertexai/chat_completions/batches_spec.rb`, `ruby_llm/providers/vertexai/gemini/batches_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr high claude/fix-fail-unreadable-vertex-maas-row 'Fail one unreadable row of a Vertex MaaS batch' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

One unreadable row loses a whole batch of an open model on Vertex AI. A tool call cut short by the token limit is enough, and every retry raises again.

```ruby
# one row of the output has a tool call whose arguments are cut off
# { "response": { "choices": [{ "message": { "tool_calls": [{ "function": { "arguments": "{\"a" } }] } }] } }

batch.results
# main:     raises, the other paid answers are unreachable
# expected: that row failed, the others returned
```

It parses the row as the other Chat Completions batches do, which fail that row alone and keep its billed usage.

Tests: `ruby_llm/providers/vertexai/chat_completions/batches_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr high claude/fix-forget-rejected-mcp-registrations-in-rails 'Forget rejected MCP registrations in Rails' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

In Rails, when an authorization server no longer knows the client RubyLLM registered, users can never reconnect. The guide says RubyLLM registers again the next time a user authorizes. That works with the in-memory store, but not with the `ruby_llm_mcp_credentials` table.

```ruby
# The registration RubyLLM stored has client_id "dyn1".
# The token endpoint answers a refresh with invalid_client.
linear.tools # raises RubyLLM::UnauthorizedError, as it should

# The server would now register a new client as "dyn2".
linear.authorization_url(redirect_uri:)
# main:     ...client_id=dyn1
# expected: ...client_id=dyn2
```

The registration row is deleted inside `MCPCredential.synchronize`, whose transaction the raised error rolls back. `OAuth` now remembers the rejected client and deletes its registration once the store's block is done.

Tests: two examples in `spec/ruby_llm/active_record/mcp_credential_spec.rb` fail on main, one for a refresh and one for a code exchange. The OAuth specs pass.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr high claude/fix-free-call-whose-result-failed-to-save 'Free a tool call whose result failed to save' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

When saving a tool result fails, the retried job returns an empty reply and sends no request.

```ruby
class ChatResponseJob < ApplicationJob
  retry_on ActiveRecord::Deadlocked

  def perform(chat_id)
    Chat.find(chat_id).with_tools(ReadLog).complete
  end
end

# First run: ReadLog runs, saving its result raises ActiveRecord::Deadlocked.
# Retry on main:
chat.complete.content # => ""
chat.running?         # => false
Chat.interrupted      # => []
# expected: the retry answers
```

The result is already in the in-memory transcript when its save fails, so the end of the round treated the call as answered and left its row claimed for up to a minute. The round now releases every call it claimed, and a claim dropped inside a save that rolled back is put back first. A call that had started counts as interrupted, like one from a crashed process: the model reads that it did not finish, and the tool does not run twice.

Tests: the crash recovery specs and the neighbouring run claim, approval and tool specs, without live requests.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr high claude/fix-keep-mcp-rate-limits-to-their-credentials 'Keep MCP rate limits to the credentials they hit' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

When one tenant hits an MCP server's rate limit, every other tenant in the process loses that server's tools until the first tenant's `Retry-After` ends.

```ruby
class SaaS < RubyLLM::MCP
  url "https://saas.example.com/mcp"
  inputs :user
  bearer_token { user.saas_token }
end

# The server answers Ada's token with 429 and Retry-After: 86400.
RubyLLM.chat.with_mcp(SaaS.new(user: ada)).ask("Hi")

# It answers Grace's token fine.
RubyLLM.chat.with_mcp(SaaS.new(user: grace)).ask("Hi")
# main: Grace's chat has no SaaS tools for 24 hours
# expected: Grace's chat has the tools
```

`Outages` keys a server by its endpoint and connection settings, not its credentials. A 429 is now kept under a key that also holds a digest of the headers and the bearer token or OAuth owner. Connection failures and 5xx statuses still sit the server out for everyone.

Limit: while any server sits out, finding a server's key evaluates its header and token blocks once more.

Tests: new examples in `spec/ruby_llm/mcp/outages_spec.rb` fail on main; the MCP specs and the chat and agent outage specs pass.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr high claude/fix-keep-attachment-with-edited-file 'Keep an attachment with the file the model edited' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

When the model edits an attached file, the next job stores the original again and points the model at it.

```ruby
chat.with_file_store.ask("Fix the total", with: "report.txt")
# the model rewrites report.txt with edit_file

job = Chat.find(chat.id).with_file_store
job.ask("And now?")
job.file_store.list.map(&:path)
# main:     ["report-2.txt", "report.txt"], and the model is told to read report-2.txt, the draft
# expected: ["report.txt"]
```

Which file an attachment became was known only to one Ruby object, and after an edit neither the blob nor the content matches. The chat file now also keeps the blob it started as, in a second Active Storage attachment, `original`, and a later process finds the file by it. There is no schema change. The original's bytes stay stored while the file exists.

Limits: files stored before this change have no `original`, so they match as before. A file that was attached and then deleted still comes back in a later process, because its row is gone; remembering that would need a column.

Tests: the file store specs and the code execution and agent specs that use a store; no live requests.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr high claude/fix-keep-streamed-interactions-citations 'Keep citations in streamed Interactions answers' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A streamed answer on Gemini's Interactions protocol loses every citation. The same answer without a block has them.

```ruby
chat = RubyLLM.chat(model: 'gemini-2.5-flash', provider: :gemini, protocol: :interactions)
              .with_provider_tools(:web_search)

chat.ask('What is the latest stable Ruby?') { |chunk| print chunk.content }.citations
# main:     []
# expected: the pages the answer cites
```

The API streams citations as `text_annotation_delta` with an `annotations` array, as the repository's own cassette shows. The stream looked for `text_annotation`, so the delta fell through and left a stray `annotations` key on the step kept for replay. This reads the event the API sends.

Tests: `interactions_spec.rb`, including its cassettes. The existing live Google Search example now also checks its citations.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr high claude/fix-keep-concurrent-results-when-a-callback-raises 'Keep concurrent results when a callback raises' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

With `concurrency: :threads` or `:fibers`, one failing message callback throws away the results of tools that already finished. The next `complete` runs those tools a second time.

```ruby
chat = RubyLLM.chat.with_tools(Lookup).with_tool_options(concurrency: :threads)
failed = false
chat.after_message do |message|
  next if failed || !message.tool_result?

  failed = true
  raise "page went away"
end

chat.ask("Look up 1, 2 and 3") # raises, as it should
chat.complete
# main: Lookup runs 5 times (1, 2, 3, then 2 and 3 again)
# expected: Lookup runs 3 times
```

`collect_results` stopped at the first error from its result callback. It now collects that error with the tool errors, records every result, and raises the first error at the end.

Tests: a spec that fails on main, and the spec files around it, with recorded cassettes replayed and nothing live.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr high claude/fix-leave-blank-assistant-text-out 'Leave blank assistant text out of replayed turns' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

Claude sometimes writes only line breaks beside a tool call or its reasoning. RubyLLM sends that blank text back as a text block, which Anthropic and Bedrock refuse ("text content blocks must contain non-whitespace text"). The tool loop fails, and so does every later request in the chat.

```ruby
chat = RubyLLM.chat(model: 'claude-haiku-4-5').with_tools(Weather)
chat.ask('What is the weather?') # the model answers "\n\n" and calls the tool
# main sends back: [{ type: "text", text: "\n\n" }, { type: "tool_use", ... }]
# expected:        [{ type: "tool_use", ... }]
```

The Anthropic and Converse renderers now leave out blank text of assistant turns. MiniMax's Anthropic dialect overrides the same step and follows it. User text is untouched.

Limit: a turn kept as the provider's own blocks is replayed as it came. The refusal rests on a report (https://github.com/agno-agi/agno/issues/3137) and was not exercised live.

Tests: the Anthropic and Converse chat specs and the MiniMax spec.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr high claude/fix-price-elevenlabs-speech-characters 'Price ElevenLabs speech by its characters' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

ElevenLabs speech never has a cost. Its speech models are priced per character in the registry, but the characters were not counted.

```ruby
RubyLLM.speak('Hello there', model: 'eleven_flash_v2_5', provider: :elevenlabs).cost.total
# main:     nil
# expected: 11 characters at the price in the registry
```

ElevenLabs speech counts its characters, streamed or not. Deepgram and xAI skipped the count too, so a price set with `config.price ..., characters:` had no effect there.

Tests: `ruby_llm/protocols/deepgram/speech_spec.rb`, `ruby_llm/protocols/elevenlabs/speech_spec.rb`, `ruby_llm/providers/xai/speech_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr high claude/fix-raise-callback-errors-instead-of-falling-back 'Raise callback errors instead of falling back' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

With fallbacks set, an error in a message callback counts as a failure of the model. The chat keeps the reply it has, asks the next model, and stores a second, billed answer.

```ruby
chat = RubyLLM.chat.with_fallbacks("gpt-4.1-mini")
chat.after_message { |message| RubyLLM.moderate(message.content) } # rate limited once
chat.ask("Hi")
# main: messages are [user, assistant, assistant]
# expected: raises RateLimitError, as without fallbacks, with messages [user, assistant]
```

Errors from message and fallback callbacks now reach the caller, as errors from the streaming block already do. Requests made inside a callback or the streaming block also keep their own retries: they inherited the setting that hands connection errors to a fallback. Errors from `before_request` still fall back, because that callback runs inside the provider request.

Tests: a spec that fails on main, and the spec files around it, with recorded cassettes replayed and nothing live.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr high claude/fix-raise-stream-ends-before-answer 'Raise when a stream ends before its answer' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

When a proxy timeout or an upstream crash closes a stream cleanly in the middle of an answer, the partial text comes back as a finished message. Nothing raises and fallbacks never run.

```ruby
chat = RubyLLM.chat(model: 'claude-haiku-4-5')
message = chat.ask('Explain Ruby') { |chunk| print chunk.content }
# the connection closes after "The answer is not"
# main:     message.content == "The answer is not", finish_reason nil
# expected: RubyLLM::ConnectionError, "Provider stream ended before completion"
```

`stream_response` now remembers whether an event ended the answer and raises `ConnectionError` otherwise. A finish reason or a Gemini continuation token ends it, and so does `[DONE]` on Chat Completions, `message_stop` on Anthropic, and `response.completed` or `response.incomplete` on Responses. Converse has its own loop and follows the same rule. `ConnectionError` is already among the errors fallbacks act on. As with any stream that delivered chunks, it is not retried.

Limits: a custom protocol that uses the shared `stream_response` must set `finish_reason` on its last chunk or override `stream_finished?`. Interactions and Mistral Conversations already raise `RubyLLM::Error` for this and are unchanged. Not exercised live beyond the cassettes.

Tests: the full suite without generators, replaying cassettes, found three specs whose stubbed streams never end; their stubs now send the event a real stream ends with. Those specs and all protocol specs pass.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr high claude/fix-refuse-message-without-its-attachment 'Refuse a message without its attachment' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A persisted chat drops an attachment it cannot read, logs a warning, and answers without it.

```ruby
# The URL answers 503.
chat.ask_later("Summarize the report", with: "https://files.example.com/report.txt")
chat.messages.last.attachments.count # => 0
chat.complete # the model gets the text alone

# expected: ask_later raises, as RubyLLM.chat.ask does
```

The rescue in `convert_to_active_storage_format` turns every read error into a missing file. A user message and a queued message now read their files first, so the error from reading reaches the caller and nothing is stored. The rescue stays for replies: one the provider already billed keeps what can be read of it. Files from Active Storage and files the provider holds are left alone.

Tests: the queue, attachment, file store and persistence specs, with the cassette-backed attachment examples; no live requests.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr high claude/fix-keep-file-nested-path 'Refuse a write_file path inside a file' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

With a `Directory` file store, a model can delete a file it never read. Writing `notes/todo.md` replaces an existing file named `notes` with a folder, past the check that stops `write_file` from replacing an unread file.

```ruby
store = RubyLLM::FileStore::Directory.new('workspace')
store.write('notes', 'Keep me')

# the model calls write_file with path: 'notes/todo.md'
store.read('notes')
# main:     the file is gone, notes is a folder now
# expected: "Keep me", and the model is told the path is inside a file
```

`write_file` refuses the path, as it already does one that is a folder. `store.write` called by an application keeps the replacement, which an existing spec states. The tool refuses on every store, including those that could have kept both.

Tests: `ruby_llm/file_store/tools_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr high claude/fix-run-the-tool-search-a-fallback-was-offered 'Run the tool search a fallback was offered' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

When a model with its own tool search (Claude, or OpenAI through Responses) falls back to one without, the fallback is offered a local `tool_search`, and calling it fails. The deferred tools stay out of reach.

```ruby
chat = RubyLLM.chat(model: "claude-haiku-4-5")
              .with_tools(Weather, defer: true)
              .with_fallbacks("gpt-4.1-mini")
chat.ask("Weather in Berlin?") # Claude answers 529
# main: the fallback calls tool_search and reads "There is no tool named `tool_search`."
# expected: the search runs and the next request offers Weather
```

Tool calls run after the chat is back on its own model, where the local tool was not registered. A `tool_search` call now finds the local tool whenever the chat has deferred tools.

Tests: a spec that fails on main, and the spec files around it, with recorded cassettes replayed and nothing live.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr high claude/fix-stop-the-chats-inside-a-tool-when-cancelled 'Stop the chats inside a tool when cancelled' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

Cancelling a chat does not stop the subagent it is running. The subagent's own checkpoint hides the one of the chat around it, so it keeps making billed requests and running tools until it is done.

```ruby
chat = RubyLLM.chat.with_tools(ResearchAgent)
chat.ask("Research this") # in a job; chat.cancel arrives during the agent's first request
# main: the agent goes on for as many requests and tool calls as it needs, then CancelledError
# expected: CancelledError at the agent's next check
```

A chat's checkpoint now checks the one around it too. It stops counting once its work ends, because threads a tool leaves running inherit it, and they should neither stop later nor renew the claim of a finished run.

Two existing examples in `chat_methods_run_claims_spec.rb` simulate a second process by calling `complete` on the same record from inside the first run. That is now nested work, so they run it in a fiber without inherited storage. What they assert is unchanged.

Tests: a spec that fails on main, and the spec files around it, with recorded cassettes replayed and nothing live.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-ask-elevenlabs-labels-without-names 'Ask ElevenLabs for speaker labels without names' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

`speaker_names: []`, which asks for speaker labels without names, sends ElevenLabs a speaker count of zero.

```ruby
RubyLLM.transcribe('meeting.wav', model: 'scribe_v2', provider: :elevenlabs, speaker_names: [])
# main:     sends diarize: true, num_speakers: 0
# expected: sends diarize: true
```

The count is left out when there are no names. [ElevenLabs takes 1 to 32](https://elevenlabs.io/docs/api-reference/speech-to-text/convert). The rejection of zero rests on that page and was not exercised live.

Tests: `ruby_llm/protocols/elevenlabs/transcription_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-bill-deleted-chat-batch-answer-once "Bill a deleted chat's batch answer once" <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

Every poll of a finished batch bills the answer of a deleted chat again.

```ruby
batch = RubyLLM.batch([chat])
chat.destroy!

3.times { RubyLLM::Batch.find(batch.id).refresh.messages }
RubyLLM::ActiveRecord::Usage.where(chat: nil).count
# main:     3
# expected: 1
```

A slot that still has its chat is marked by the answer in it. A deleted chat has no such mark, so each new `Batch` object counts its slot as undelivered. The slot's id in `ruby_llm_batches.chat_ids` now becomes `nil` in the transaction that records the usage, and a `nil` slot counts as delivered. The id no longer pointed at a row, the array keeps its length, and there is no schema change. The answer itself is still returned by `messages`.

Tests: the batch and usage ledger specs; no live requests.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-build-openrouter-chunks-like-the-shared-protocol 'Build OpenRouter chunks like the shared protocol' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

Streaming from OpenRouter ignores `split_think_tags` and drops content filters. The same answers without a block honor both.

```ruby
RubyLLM.configure { |config| config.split_think_tags = true }
chat = RubyLLM.chat(model: 'deepseek/deepseek-r1-0528', provider: :openrouter)

chat.ask('Hi') { |chunk| print chunk.content }.content # the model sends "<think>hm</think>hi"
# main:     "<think>hm</think>hi"
# expected: "hi"
```

OpenRouter had its own copy of `build_chunk`, which fell behind the shared one. The shared builder now reads reasoning through `parse_thinking_text` and `parse_thinking_signature`, as plain answers do, so OpenRouter only overrides how its reasoning details accumulate. Its copy of `build_chunk` is gone.

Limit: whether OpenRouter forwards content filter results was not checked live. Other Chat Completions providers now read the same thinking fields streamed as plain, which adds `thinking` and `signature`.

Tests: the Chat Completions specs, all provider specs and `chat_streaming_spec.rb`, including cassettes. `provider_coverage.json` names the method that replaced `build_chunk`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-cancel-a-chat-that-waits-on-a-person 'Cancel a chat that waits on a person' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

`cancel` on a chat that waits for an approval or an answer does nothing: the flag is cleared without an error, the calls stay open, and a later approval runs the cancelled tool. A chat waiting on a task cancels as documented.

```ruby
chat.ask("Delete the records") # waits for approval
chat.cancel
chat.complete
# main: returns the pending response, chat.waiting? is still true
# expected: CancelledError, and the calls are closed as unfinished

chat.ask("Never mind")
# main: PendingToolCallsError
```

The loop stops without reaching a checkpoint while it waits. It now checks once before it clears the flag, and closes the calls as it does for other cancellations.

Tests: a spec that fails on main, and the spec files around it, with recorded cassettes replayed and nothing live.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-close-cancelled-calls-whose-task-fails-to-cancel 'Close cancelled calls whose task fails to cancel' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

`Task#cancel` is application code, so it can raise anything. An error outside RubyLLM's and Faraday's escapes while a chat is being cancelled, replaces `CancelledError`, and leaves the call open.

```ruby
class RenderTask < RubyLLM::Task
  def cancel = JobApi.stop(data["id"]) # Net::OpenTimeout
end

chat.cancel
chat.complete
# main: Net::OpenTimeout, and every later ask raises PendingToolCallsError
# expected: CancelledError, and the call is closed
```

Cancelling a task now rescues `StandardError`, including one from building the task, and logs it as before.

Tests: a spec that fails on main, and the spec files around it, with recorded cassettes replayed and nothing live.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-count-seconds-streamed-transcriptions 'Count the seconds of streamed transcriptions' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A streamed transcription billed by the second has no cost, while the same file without a block has one.

```ruby
RubyLLM.transcribe('meeting.wav', model: 'scribe_v2_realtime', provider: :elevenlabs) { |chunk| print chunk.delta }.cost.total
# main:     nil
# expected: the seconds at the price in the registry
```

Streamed ElevenLabs, Deepgram, and xAI transcriptions set a duration but not the billed seconds. They set both now.

Tests: `ruby_llm/protocols/deepgram/streaming_transcription_spec.rb`, `ruby_llm/protocols/elevenlabs/streaming_transcription_spec.rb`, `ruby_llm/protocols/xai/streaming_transcription_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-end-cancelled-expired-video-jobs 'End cancelled and expired video jobs' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A video job that was cancelled or expired on OpenRouter, or cancelled on MiniMax, never finishes. Waiting on it polls until the timeout.

```ruby
job.refresh.status   # the provider says "expired" or "cancelled"
# main:     still pending
# expected: failed
```

These states end the job as failed. See [OpenRouter](https://www.openrouter.ai/docs/api/api-reference/video-generation/poll-video-generation-status.md) and [MiniMax](https://platform.minimax.io/docs/api-reference/video-generation-v2-query.md). This rests on the documentation and was not exercised live.

Tests: `ruby_llm/providers/minimax_media_spec.rb`, `ruby_llm/providers/openrouter/videos_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-evaluate-the-result-a-tool-halted-with 'Evaluate the result a tool halted with' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

Evaluating an agent that ends its turn with `halt` sees an empty output, because the last assistant message only holds the tool call.

```ruby
class FileBug < RubyLLM::Tool
  def execute = halt("Filed as bug #12")
end

chat.ask("File it").content                    # => "Filed as bug #12"
RubyLLM::Evaluation::Evidence.new(chat).output # what the evaluation and the judge see
# main: ""
# expected: "Filed as bug #12"
```

Evidence now takes the halted result when the last turn ended with one, as `ask` does.

Tests: a spec that fails on main, and the spec files around it, with recorded cassettes replayed and nothing live.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-finish-open-reply-in-the-chat-ui 'Finish an open reply when the chat UI gets a message' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A bug in one tool leaves a chat in the generated UI without a way forward.

```ruby
class Lookup < RubyLLM::Tool
  description "Looks up"

  def execute
    {}.fetch(:missing) # KeyError
  end
end

# The job fails, and the page says "The reply failed. Send your message again."
# Sending again, on main: "Answer the questions above to continue.", no questions, no job.
# expected: the reply gets another run
```

An error that is not one of RubyLLM's leaves its call open, which is documented. The generated messages controller rescued the resulting `PendingToolCallsError` as if a person owed an answer. When there are no pending questions it now enqueues the chat job, which finishes the open reply, and asks for the message again. A tool that still raises fails that run too.

An app that already generated its controller needs to run the generator again or copy the change.

Tests: the chat UI generator specs, which boot the generated apps; no live requests. Three examples in that file compare the last line of generator output and fail here on main too, on a proxy warning printed after it.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-forget-the-tokens-of-a-revoked-mcp-grant 'Forget the tokens of a revoked MCP grant' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

`authorized?` stays `true` after the user revokes the grant. The guide says to check it before showing a chat that needs the server, so the app shows the chat, which fails, and never offers to connect again.

```ruby
# Ada removed the app in Linear, so a refresh answers invalid_grant.
linear = Linear.new(user: ada)
linear.tools # raises RubyLLM::UnauthorizedError, as it should

Linear.new(user: ada).authorized?
# main: true, and every request tries the dead refresh token again
# expected: false
```

When a refresh answers `invalid_grant`, `OAuth` now drops the access and refresh tokens and keeps the client. A refresh that fails for another reason keeps them, as before. `docs/_tools/mcp.md` and the RDoc of `authorized?` say so.

`invalid_grant` is the error RFC 6749 defines for a refresh token that is invalid, expired, or revoked: https://datatracker.ietf.org/doc/html/rfc6749#section-5.2. Not exercised against a live server.

This touches the same line as the pull request that refreshes with the configured secret, so whichever merges second needs a small rebase.

Tests: a new example in `spec/ruby_llm/mcp/oauth_spec.rb` fails on main. The MCP specs and the Active Record credential specs pass.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-give-mcp-writes-to-a-process-a-deadline 'Give MCP writes to a process a deadline' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A stdio MCP server that stops reading hangs every thread that uses it once a tool argument is larger than the pipe buffer (64 KB on Linux). Neither `timeout` nor `chat.cancel` ends the wait.

```ruby
class Notes < RubyLLM::MCP
  command "ruby", "-e", "sleep"
  timeout 2
end

Notes.new.call(:save, text: "x" * 200_000)
# main: blocks forever, holding the server's lock
# expected: raises RubyLLM::MCP::Stdio::Unavailable after 2 seconds
```

Reads already follow the deadline and check for cancellation, but writes used a blocking `puts`. They now write what fits, wait with the same deadline and check, and read what the server wrote meanwhile, so a server blocked on its own full stdout can go on. A process that got only part of a message is stopped, since the rest can't follow, and starts again with the next request. Cancelling a request no longer starts a process that isn't running.

Tests: four new examples in `spec/ruby_llm/mcp/stdio_spec.rb` fail on main. The MCP specs pass. Not run on Windows.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-give-calls-without-an-id-their-own 'Give tool calls sent without an id their own' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

Some Chat Completions servers send tool calls without an `id`. Streaming handles this by assigning one. A plain request does not:

```ruby
chat = context.chat(model: 'gpt-oss:20b', provider: :openai, protocol: :chat_completions,
                    assume_model_exists: true).with_tools(Weather)
chat.ask('What is the weather in Paris and London?') # two calls, no ids
# main:     RubyLLM::Error, "Duplicate tool call ID in one response: nil"
# expected: both tools run and their results join their calls
```

With a single call the tool runs, but the next request carries a result without `tool_call_id` and an extra `{"error":"The tool call did not finish."}` result.

A complete response now assigns an id to each call that has none, as the stream does. Mistral's protocols share the parser. Responses that carry ids are unchanged.

Tests: the Chat Completions and Mistral protocol specs, including cassettes.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-ignore-reported-cost-cost-for 'Ignore a reported cost in Model#cost_for' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

`Model#cost_for` prices tokens with the model you call it on, but an amount the provider reported wins. Every model in a comparison then costs what the original one billed.

```ruby
tokens = RubyLLM::Tokens.new(input: 1_000_000, reported_cost: 9.99)

model.cost_for(tokens).total   # a model at $1 per million input tokens
# main:     9.99
# expected: 1.0
```

`cost_for` ignores a reported amount. `response.cost` still uses it. A request with only a reported amount has no tokens to price, so its `cost_for` total is `nil`.

Tests: `ruby_llm/model_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-inline-remote-files-on-vertex-claude 'Inline remote files for Claude on Vertex AI' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

Claude on Vertex AI gets a remote image or PDF as a URL, which Vertex AI does not support.

```ruby
RubyLLM.chat(model: 'claude-haiku-4-5', provider: :vertexai)
       .ask('What is this?', with: 'https://example.com/ruby.png')
# main sends: { type: "image", source: { type: "url", url: "https://example.com/ruby.png" } }
# expected:   { type: "image", source: { type: "base64", media_type: "image/png", data: "..." } }
```

Claude on Bedrock already sends the bytes for the same reason. That code moves unchanged into `Protocols::Anthropic::InlineSources`, and both hosts include it. Vertex AI batches use the same renderer.

Anthropic lists URL sources as unsupported on Vertex AI: https://platform.claude.com/docs/en/build-with-claude/claude-on-vertex-ai. Not exercised live.

Tests: the Vertex AI, Bedrock Anthropic and file preprocessing specs.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-keep-chat-on-its-unlisted-model 'Keep a chat on its unlisted model in the chat UI' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

The generated chat UI moves a chat to the default model once its own model is unlisted.

```ruby
chat.model_id # => "gpt-4.1-nano"
# The provider stops listing it: the row stays, with unlisted_at set.
# A person opens the chat and sends "Hi" without touching the picker.
chat.reload.model_id
# main:     the default model
# expected: "gpt-4.1-nano"
```

`available_chat_models` leaves unlisted models out, so the form has no selected option, the browser picks the first one, "Default", and the controller reads its blank value as a choice. The model picker in a chat's form now also offers the chat's own model when the list lacks it, in both view sets. Choosing the default entry still switches to the default model.

An app that already generated its views needs to run the generator again or copy the two lines.

Tests: the chat UI generator specs, which boot the generated apps; no live requests. Three examples in that file compare the last line of generator output and fail here on main too, on a proxy warning printed after it.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-keep-spreadsheet-rows-one-line 'Keep spreadsheet rows on one line in read_file' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A spreadsheet cell with a line break splits its row in two, so the model reads the columns after it under the wrong row.

```ruby
# a row with the cells "12 Main St\nBerlin" and 42
# read_file shows
# main:     12 Main St
#           Berlin    42
# expected: 12 Main St Berlin    42
```

Tabs and breaks inside a cell become spaces, as they already do in Word tables.

Tests: `ruby_llm/file_store/converters/office_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-keep-tool-search-results-out-of-the-context-budget 'Keep tool search results out of the context budget' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

With `with_context_budget(per_result:)` and a small window, deferred tools never load. The chat reads the tools a search found back from its JSON result, and the budget cut that JSON.

```ruby
chat = RubyLLM.chat(model: "mistral-small-latest")
              .with_tools(*many_tools, defer: true)
              .with_context_budget(window: 8192, per_result: 0.1)
chat.ask("Find the invoice tools") # the model searches
# main: the next request offers only tool_search
# expected: it offers the tools the search found
```

Tool search results are no longer cut per result, as they already are not moved to a file store.

Tests: a spec that fails on main, and the spec files around it, with recorded cassettes replayed and nothing live.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-limit-the-skipped-files-a-code-run-names 'Limit the skipped files a code run names' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

Code that writes many files, such as a script that unpacks an archive, sends the name of every file RubyLLM did not return to the model. Standard output is cut to 20,000 characters and returned files to 10, but this list has no limit.

```ruby
chat.with_code_execution
chat.ask("Unpack the archive and list what is in it") # the code writes 20,000 files
# main: a 1.3 MB tool result, sent again with every later request
# expected: a short report
```

The report now names the first 50 skipped files and counts the rest (`19940 more files`). Chats with a file store already cut this result down.

Tests: a new example in `spec/ruby_llm/chat_code_execution_spec.rb` fails on main. The code execution specs pass.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-load-chats-whose-usage-owner-class-is-gone 'Load chats whose usage owner class is gone' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

Renaming or removing the class of a usage owner makes every chat it paid for raise.

```ruby
RubyLLM.with_owner(account) { chat.ask("Hello") }
# a later deploy renames Account to Workspace

Chat.find(chat.id).ask("Hello again")
# main:     NameError: uninitialized constant Account
# expected: the chat answers
```

`ruby_llm_usages` keeps `owner_type` forever, and loading a chat preloads the owner of every usage row. `ChatQueue#queued_sender` already reads a missing class as no sender. Usage rows now do the same when a chat loads: an owner whose class is gone is `nil` on the entry, and the row keeps its columns. If the preload fails, the remaining owners load one at a time.

Reading `usage.owner` on the row itself still raises, as any Rails association does, and so do chat files with such an owner.

Tests: the usage ledger, chat methods, owner and batch specs; no live requests.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-match-crlf-files-edit-file 'Match CRLF files in edit_file' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

`edit_file` cannot change more than one line at a time in a CRLF file. `read_file` shows every line ending as LF, so the text the model quotes back never matches.

```ruby
store.write('notes.txt', "one\r\ntwo\r\n")

# the model calls edit_file with old_text "one\ntwo" and new_text "1\n2"
# main:     an error, the text is not in the file
# expected: "1\r\n2\r\n"
```

When every line of a file ends in CRLF, the texts of the edit take the same ending. Files with mixed endings behave as before.

Tests: `ruby_llm/file_store/tools_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-give-root-url-attachments-no-slash-as-name "Never name an attachment after a root URL's slash" <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

Attaching a web page by its root URL makes every `run_code` call in the chat raise.

```ruby
chat.with_code_execution
chat.ask("Count the words on this page with code", with: "https://example.com/")
# main: Errno::EISDIR from ask, and from every later run
# expected: the code reads the page at attachments/file
```

`File.basename("/")` is `"/"`, so the attachment's filename was `/`. The run wrote to the attachments directory itself. The slash is now left out, which gives the empty name `https://example.com` without a slash already has. Code execution and file stores call such a file `file`.

Tests: new examples in `attachment_spec.rb` and `chat_code_execution_spec.rb` fail on main. The attachment, code execution, and file store specs pass.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-parse-the-final-answer-of-a-rebuilt-message 'Parse the final answer of a rebuilt message' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A Responses reply with commentary before its final answer parses fine until it is rebuilt from `to_h`.

```ruby
reply = chat.with_schema(Invoice).ask("What is the total?")
reply.parsed                              # => {"total" => 12.1}
RubyLLM::Message.new(reply.to_h).parsed
# main: JSON::ParserError, the commentary is parsed too
# expected: {"total" => 12.1}
```

Finding the final answer read the provider from usage entries, which a rebuilt message does not have. It now uses `Message#provider`, which knows both sources.

Tests: a spec that fails on main, and the spec files around it, with recorded cassettes replayed and nothing live.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-price-a-rebuilt-message-at-its-own-provider 'Price a rebuilt message at its own provider' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A message rebuilt from `to_h` names its provider, but looks its model up by ID alone. When several providers share the ID, it is priced at another provider's rates.

```ruby
message = RubyLLM::Message.new(role: :assistant, content: "Hi", model: "mistral-medium-3", provider: "vertexai",
                               input_tokens: 1_000_000, output_tokens: 1_000_000)
RubyLLM::Message.new(message.to_h).model_info.provider
# main: "mistral"
# expected: "vertexai"
```

`model_info` now passes the provider the message names. When that provider has no such model, the cost is unknown rather than another provider's. Looking up with a provider can raise `ConfigurationError` for a misconfigured deployment, so a price lookup rescues that too.

Tests: a spec that fails on main, and the spec files around it, with recorded cassettes replayed and nothing live.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-price-advisor-tokens-own-model "Price advisor tokens with the advisor's own model" <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

When Anthropic's advisor tool runs, its tokens are priced at the rate of the model you asked, not of the advisor.

```ruby
# claude-haiku-4-5 answers, with claude-opus-4-5 as its advisor
response = chat.with_provider_tools(advisor_tool).ask('Plan the migration')

response.cost.total   # executor ran up $0.00446, advisor $0.04442
# main:     0.01334
# expected: 0.04888
```

[Anthropic lists what the advisor ran in `usage.iterations`](https://platform.claude.com/docs/en/agents-and-tools/tool-use/advisor-tool), billed at its own rates and left out of the top-level counts. Those tokens get a usage entry of their own, with the advisor as its model, on Anthropic and on Bedrock, streamed or not. This rests on the documentation and was not exercised live. Limits: message batch rows no longer misprice advisor tokens, but leave the advisor's own cost out, and a stream cancelled before its end records none.

Tests: `ruby_llm/protocols/anthropic_advisor_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-raise-minimax-stream-errors 'Raise MiniMax errors inside a transcription stream' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A MiniMax error during a streamed transcription comes back as a success with an empty or partial transcript.

```ruby
# MiniMax answers 200 with
# { "base_resp": { "status_code": 1008, "status_msg": "insufficient balance" } }

RubyLLM.transcribe('meeting.wav', model: 'asr-1.0', provider: :minimax, assume_model_exists: true) { |chunk| print chunk.delta }
# main:     an empty transcription
# expected: RubyLLM::PaymentRequiredError
```

The error is raised, whether it is the whole body or an event, as it is without a block. A stream that ends before its final event raises too, as the other streamed transcriptions do. The recorded stream still passes; the errors are stubbed and were not exercised live.

Tests: `ruby_llm/providers/minimax_media_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-raise-rubyllm-errors-for-failed-url-downloads 'Raise RubyLLM errors for failed URL downloads' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A URL attachment that answers 403 or 404, or whose host does not answer, raises a raw Faraday error, which `rescue RubyLLM::Error`, `retry_on`, and `rescue_from` miss.

```ruby
chat.ask("What is in this file?", with: "https://cdn.example.com/a.csv?signature=expired")
# main: Faraday::ForbiddenError
# expected: RubyLLM::Error, "Download from cdn.example.com failed with status 403"

chat.ask("And this one?", with: "https://unreachable.example.com/a.csv")
# main: Faraday::ConnectionFailed
# expected: RubyLLM::ConnectionError, with the Faraday error as its cause
```

`Connection.download` already meant to raise `RubyLLM::Error` for a failed status, but Faraday's `raise_error` middleware raised first. It now turns both cases into RubyLLM errors. Images, videos, and the MiniMax, ElevenLabs, and Cohere downloads share the method.

**This changes an expectation an existing spec pins.** "return errors when content doesn't exist" in `spec/ruby_llm/chat_content_spec.rb` expected `Faraday::ResourceNotFound`. It now expects `RubyLLM::Error`. Applications that rescue the Faraday classes must change them, so `upgrading.md` says so in "Network Failures Raise RubyLLM::ConnectionError".

Two consequences: a chat with fallbacks treats an unreachable attachment host as a connection failure, so it tries its fallback model, and the chat still fails on later turns while the dead URL stays in its messages.

Tests: new examples in `spec/ruby_llm/attachment_spec.rb` fail on main. The attachment, image, video, transport, and protocol specs pass, with the recorded live examples in the touched files.

## Type of change

- [x] Bug fix
- [ ] New feature
- [x] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [x] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [ ] No API changes
PRBODYEND
open_pr medium claude/fix-raise-rubyllm-errors-for-malformed-bodies 'Raise RubyLLM errors for malformed 200 bodies' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A 200 response whose error is a String, or a proxy's web page with a 200, raises a plain Ruby error. `rescue RubyLLM::Error` and fallbacks miss it.

```ruby
# the server answers 200 {"error":"overloaded"}
RubyLLM.chat(model: 'gpt-5-nano', protocol: :chat_completions).ask('Hi')
# main:     TypeError: String does not have #dig method
# expected: RubyLLM::ServerError: overloaded (what the same body raises when streamed)

# a proxy answers 200 <html>Sign in</html>
# main:     NoMethodError
# expected: RubyLLM::Error: Provider returned an unreadable response body
```

Chat Completions, its embeddings, and Responses now raise any error the body carries, the same test the stream uses. `parse_completion_response` refuses a body that is not an object, beside the existing check for an empty one.

Limits: an error object without a message now raises too, as it does in a stream. Moderation reads errors its own way and is unchanged.

Tests: the protocol, Chat Completions, Responses and provider specs, including cassettes.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-raise-the-http-error-classes-over-websockets 'Raise the HTTP error classes over WebSockets' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

Streamed transcription over a WebSocket (Deepgram, ElevenLabs, xAI, Gemini Live) raises raw Ruby errors when the connection fails, and a plain `RubyLLM::Error` when the provider refuses the handshake. Over HTTP the same failures raise `RubyLLM::ConnectionError` and `RubyLLM::UnauthorizedError`.

```ruby
RubyLLM.transcribe("call.wav", provider: :deepgram, model: "nova-3-general") { |chunk| print chunk.text }
# The connection is refused:
#   main: Errno::ECONNREFUSED
#   expected: RubyLLM::ConnectionError
# The API key is wrong:
#   main: RubyLLM::Error, "Error during WebSocket handshake: Unexpected response code: 401"
#   expected: RubyLLM::UnauthorizedError
```

`WebsocketConnection` now turns refused, dropped, timed out, and TLS failures into `ConnectionError`, with `timeout?` true for a timeout, and gives a refused handshake the class of its HTTP status, with its `Retry-After`. A close frame with an error code still raises `RubyLLM::Error`. Nothing is retried here.

**This changes an expectation an existing spec pins.** "rejects an untrusted TLS certificate" in `spec/ruby_llm/transport/websocket_connection_spec.rb` expected `OpenSSL::SSL::SSLError`. It now expects `RubyLLM::ConnectionError`, with the same message. Applications that rescue the Ruby classes must change them, so `upgrading.md` says so in "Network Failures Raise RubyLLM::ConnectionError".

Limit: the handshake's response body is not read, so its error carries the default message of its class.

Tests: new examples over real sockets in `websocket_connection_spec.rb` fail on main. The transport, protocol, and transcription specs pass, with the recorded live transcription examples. Not exercised against a live provider.

## Type of change

- [x] Bug fix
- [ ] New feature
- [x] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [x] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [ ] No API changes
PRBODYEND
open_pr medium claude/fix-reference-xai-edit-images-id 'Reference uploaded images by id in xAI edits' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

Editing an image already uploaded to xAI sends its file id as a URL.

```ruby
file = RubyLLM.upload('logo.png', provider: :xai)
RubyLLM.paint('Make it blue', with: file, model: 'grok-imagine-image', provider: :xai)
# main:     sends the id under url
# expected: sends the id under file_id
```

The edits endpoint [takes `file_id` in place of `url`](https://docs.x.ai/developers/model-capabilities/imagine/files/inputs.md), and xAI videos already send it that way. This rests on the documentation and was not exercised live.

Tests: `ruby_llm/providers/xai/images_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-refresh-mcp-grants-with-the-configured-secret 'Refresh MCP grants with the configured secret' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

Rotating the client secret of an app you registered with an MCP server disconnects every user. RubyLLM keeps refreshing with the secret the app had when each user authorized.

```ruby
class Slack < RubyLLM::MCP
  url "https://mcp.slack.com/mcp"
  inputs :user
  oauth owner: :user, client_id: "app", client_secret: ENV["SLACK_CLIENT_SECRET"]
end

# Ada authorized while the secret was "old-secret". It is "new-secret" now,
# and her access token expired.
Slack.new(user: ada).tools
# main: refreshes with app:old-secret, is refused, raises RubyLLM::UnauthorizedError
# expected: refreshes with app:new-secret
```

The refresh now sends the configured secret when the grant belongs to the configured `client_id`. A grant to another client, or to one RubyLLM registered itself, keeps the secret stored with it. Private keys already work this way.

Tests: a new example in `spec/ruby_llm/mcp/oauth_spec.rb` fails on main. The MCP specs pass.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-replace-invalid-bytes-in-mcp-results 'Replace invalid bytes in MCP results' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

One byte that is not UTF-8 in an MCP tool result breaks the chat for good. A server only has to return a Latin-1 byte from a file, a log line, or a database.

```ruby
# The tool result holds the bytes "caf\xE9".
chat.with_mcp(files).ask("Read the menu")
chat.ask("Never mind")
# main: both raise JSON::GeneratorError (source sequence is illegal/malformed utf-8)
# expected: the model reads the result as "caf�", and the chat goes on
```

Event streams already replace such bytes before they are parsed. JSON bodies over HTTP and the lines a stdio server writes now do too.

Tests: one new example each in `spec/ruby_llm/mcp/http_spec.rb` and `stdio_spec.rb` fails on main. The MCP specs pass.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-report-the-error-an-around-tool-call-block-rescues 'Report the error an around_tool_call block rescues' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A tool that raises after doing its work, inside an `around_tool_call` block that rescues the error, is reported to the model as not run. The model then calls it again.

```ruby
chat.around_tool_call do |call, &run|
  run.call
rescue StandardError => e
  ErrorTracker.notify(e)
end
chat.ask("Pay the invoice") # Pay charges, then raises "printer offline"
# main: {"error":"The pay call did not run."}
# expected: {"error":"printer offline"}
```

The result now starts as "did not run" and becomes the tool's result or its error once the tool runs. A block may still call `run` again after a failure.

Tests: a spec that fails on main, and the spec files around it, with recorded cassettes replayed and nothing live.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-resume-unfinished-reply-below-instructions 'Resume an unfinished reply below new instructions' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A Gemini reply paused with a continuation token loses its first part when the next process sets run-time instructions, as `Agent.find` does.

```ruby
class Writer < RubyLLM::Agent
  chat_model Chat
  instructions "Be brief"
end

Writer.find(id).ask("Think") # saves "One ", then the provider fails
Writer.find(id).complete.content
# main:     "two", and the row holds only "two"
# expected: "One two"
```

`with_instructions` appends the system message, so the unfinished reply is no longer the last message and the run does not resume it. `with_instructions` now inserts before an unfinished reply, so plain chats get the same order.

Limit: instructions saved as a message record behind the unfinished reply still end up after it when the chat is loaded again.

The Gemini responses in the spec are stubs; I did not exercise this live. Tests: the long decode, instructions, compaction and Gemini protocol specs.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-retry-the-statuses-cloudflare-gives-a-dead-origin 'Retry the statuses Cloudflare gives a dead origin' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A provider behind Cloudflare answers 520 to 524 when its own servers are down or slow. RubyLLM raises a plain `RubyLLM::Error` for those, and for a 408, so it neither retries them nor moves on to a fallback.

```ruby
chat = RubyLLM.chat.with_fallbacks(backup_model)
chat.ask("Hello")
# The provider answers 502: four requests, then the fallback answers
# The provider answers 522, on main: one request, then RubyLLM::Error
# expected: the same as 502
```

408 and 520 to 524 now raise `RubyLLM::ServiceUnavailableError`, which is already retried and in the default fallback list. 525 and 526, which report a certificate problem on the origin, stay plain errors. A rescue of `RubyLLM::Error` still catches these.

Cloudflare documents the codes: https://developers.cloudflare.com/support/troubleshooting/http-status-codes/cloudflare-5xx-errors/. Not exercised against a live provider.

Tests: new examples in `spec/ruby_llm/transport/error_middleware_spec.rb` fail on main. The transport, error, and fallback outage specs pass.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-return-a-subagents-rescued-value-to-its-parent "Return a subagent's rescued value to its parent" <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

An agent with `rescue_from` crashes the chat that uses it as a tool.

```ruby
class ResearchAgent < RubyLLM::Agent
  description "Researches a question"
  rescue_from(RubyLLM::RateLimitError) { "Research is busy." }
end

RubyLLM.chat.with_tools(ResearchAgent).ask("Research this") # the agent is rate limited
# main: NoMethodError: undefined method 'content' for an instance of String
# expected: the tool result is "Research is busy."
```

`ask` returns the handler's value, which need not be a message. The tool now returns that value as it is.

Tests: a spec that fails on main, and the spec files around it, with recorded cassettes replayed and nothing live.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-run-a-branchs-agent-callbacks-on-its-own-agent "Run a branch's agent callbacks on its own agent" <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A chat copied with `dup` and handed to another agent instance keeps running its callbacks on the first agent, with the first user's inputs.

```ruby
class SupportAgent < RubyLLM::Agent
  inputs :user
  after_message { |message| Audit.log(user, message) }
end

alice = SupportAgent.new(user: "alice")
bob = SupportAgent.new(chat: alice.chat.dup, user: "bob")
bob.ask("Hello")
# main: logged for alice
# expected: logged for bob
```

The registered blocks held the source chat's table of agents. A copy now builds its agent callbacks again for its own table, in the same order among the other callbacks.

Tests: a spec that fails on main, and the spec files around it, with recorded cassettes replayed and nothing live.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-send-assistant-attachments-to-converse-as-user 'Send assistant attachments to Converse as user turns' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A chat that holds an image the assistant produced fails when it continues on Bedrock Converse.

```ruby
chat = RubyLLM.chat(model: 'gemini-2.5-flash-image')
chat.ask('Draw a ruby')
chat.with_model('amazon.nova-lite-v1:0', provider: :bedrock).ask('Describe your drawing')
# main sends: { role: "assistant", content: [{ text: "..." }, { image: ... }] }
# expected:   the image in the user message that follows
```

Converse documents that images and documents are only allowed when the role is `user`: https://docs.aws.amazon.com/bedrock/latest/APIReference/API_runtime_Message.html. The attachments now go into the next user message under "Attachments from the assistant:", behind any tool results, as Chat Completions and Responses already do.

Limits: the refusal rests on that page and was not exercised live. A turn with only attachments leaves two user messages in a row, as a turn that renders to nothing already does. Claude through InvokeModel is unchanged.

Tests: the Converse protocol and Bedrock provider specs, including cassettes.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-send-instructions-set-on-found-chat 'Send instructions saved on a chat an agent found' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

Instructions set on a chat loaded with `Agent.find` are saved but never sent.

```ruby
class Support < RubyLLM::Agent
  chat_model Chat
  instructions "You are helpful"
end

chat = Support.find(id)
chat.with_instructions("Answer in French")
chat.messages.where(role: :system).pluck(:content) # => ["Answer in French"]
chat.to_llm.messages.first.content
# main:     "You are helpful"
# expected: "Answer in French"
```

`Agent.find` applies its instructions with `persist: false`, and every sync applies those again over the saved rows. Now replacing the saved instructions drops the applied replacement, and appending with `append: true` adds to the applied ones as well as to the saved rows. Applied additions, such as today's date, stay.

Limit: instructions another process appended stay covered by the agent's own, as today, since the record cannot tell them from what the agent saved before.

Tests: the chat methods, agent and persistence specs; no live requests.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-skip-fallbacks-rubyllm-cannot-ask-to-think 'Skip fallbacks RubyLLM cannot ask to think' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

With thinking on, a fallback that has no thinking control raises `ArgumentError`. That hides the provider's error, and the fallbacks after it are never tried.

```ruby
chat = RubyLLM.chat(model: "claude-haiku-4-5").with_thinking
              .with_fallbacks("gpt-4.1-mini", "gpt-5.4-mini")
chat.ask("Hi") # Claude answers 529
# main: ArgumentError: RubyLLM does not know how to enable thinking for openai/gpt-4.1-mini
# expected: gpt-5.4-mini answers
```

Such a fallback is now skipped with the same warning as an unknown model or a provider without a key. When none is left, the original error is raised. A request on the chat's own model raises as before.

Tests: a spec that fails on main, and the spec files around it, with recorded cassettes replayed and nothing live.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-stop-repeating-xai-utterances 'Stop repeating long xAI utterances' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A streamed xAI transcription repeats any utterance longer than one chunk, in the text, segments, words, and deltas.

```ruby
# xAI sends "The balance is", then "on the statement",
# then the whole: "The balance is, on the statement today."

transcription.text
# main:     The balance is on the statement The balance is, on the statement today.
# expected: The balance is on the statement today.
```

xAI locks an utterance in chunks and [then restates it whole](https://docs.x.ai/developers/model-capabilities/audio/speech-to-text.md) ([Pipecat describes the same](https://docs.pipecat.ai/api-reference/server/services/stt/xai.md)). Only the words its chunks left out are kept, judged by word timestamps. Limits: where the final rewords a locked chunk, the locked text stands, and events without words behave as before. The recorded stream has one chunk, so a longer utterance was not exercised live.

Tests: `ruby_llm/protocols/xai/streaming_transcription_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-keep-model-text-in-rich-text-content 'Store model text in rich text content as text' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

With `has_rich_text :content` on the message model, a saved reply or tool result loses everything that looks like a tag.

```ruby
class Message < ApplicationRecord
  acts_as_message
  has_rich_text :content
end

chat.add_message(role: :assistant, content: "Use `<script>` and a<b")
Chat.find(chat.id).to_llm.messages.last.content
# main:     "Use `"
# expected: "Use `<script>` and a<b"
```

Action Text reads an assigned String as HTML. Text from the model and from tools is now escaped, with its line breaks, before it is assigned, so it displays and reads back as it was written. A user's message is assigned as before, since a rich text editor sends HTML.

Limits: instructions set with `with_instructions` are still assigned as HTML, and rows saved before this change keep what they lost.

Tests: the Action Text, attachment, message and persistence specs; no live requests.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr medium claude/fix-time-out-mcp-requests-kept-alive-by-comments 'Time out MCP requests kept alive by comments' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

An MCP server's `timeout` never fires over HTTP while the server or a proxy sends keep-alive comments, which is common for event streams. A stuck tool call waits forever.

```ruby
class Reports < RubyLLM::MCP
  url "https://reports.example.com/mcp"
  timeout 2
end

# The server opens an event stream and sends ": ping" every half second.
Reports.new.call(:render)
# main: still waiting after 20 seconds
# expected: raises RubyLLM::ConnectionError after 2 seconds
```

`timeout` is documented as how many seconds a request may take, but over HTTP it was only the wait for the next bytes. An event stream now also times out when that long has passed since the request was sent or since the server's last message. Progress starts the time again, so long calls that report it still finish. Subscriptions have no limit, as before, and JSON bodies are untouched. The MCP specification allows resetting the clock on progress: https://modelcontextprotocol.io/specification/2025-06-18/basic/lifecycle#timeouts. Not exercised against a live server.

Tests: two new examples over a real socket in `spec/ruby_llm/mcp/http_spec.rb`; the keep-alive one fails on main. The MCP specs pass.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-accept-flv-video-on-bedrock 'Accept FLV video on Bedrock Converse' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

An FLV video raises on Bedrock Converse, although the code lists FLV as a format Converse takes.

```ruby
RubyLLM.chat(model: 'amazon.nova-lite-v1:0', provider: :bedrock).ask('What happens here?', with: 'clip.flv')
# main:     RubyLLM::UnsupportedAttachmentError (video/x-flv)
# expected: a video block with format "flv"
```

The MIME type of an FLV file is `video/x-flv`, and the alias table had no entry for it. Converse lists it: https://docs.aws.amazon.com/bedrock/latest/APIReference/API_runtime_VideoBlock.html. Not exercised live.

Tests: the Converse media specs.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-accept-mka-audio-on-bedrock 'Accept MKA audio on Bedrock Converse' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

Matroska audio raises on Bedrock Converse, although the code lists MKA as a format Converse takes.

```ruby
RubyLLM.chat(model: 'mistral.voxtral-small-24b-2507', provider: :bedrock).ask('What is said?', with: 'talk.mka')
# main:     RubyLLM::UnsupportedAttachmentError (audio/x-matroska)
# expected: an audio block with format "mka"
```

The MIME type of an MKA file is `audio/x-matroska`. The video alias table maps `x-matroska` to `mkv`; the audio table had no entry for it. Converse lists it: https://docs.aws.amazon.com/bedrock/latest/APIReference/API_runtime_AudioBlock.html. Not exercised live.

Tests: the Converse media specs.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-announce-mcp-changes-once-the-client-connected 'Announce MCP changes once the client connected' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

An MCP server that announces a change before it answers `initialize` cannot be used when an `after_change` callback asks the server for something.

```ruby
class Files < RubyLLM::MCP
  command "files-server"
  after_change { tools }
end

# The server sends notifications/tools/list_changed before its initialize result.
Files.new.tools
# main: ThreadError (deadlock; recursive locking), every time
# expected: the tools
```

The callback ran while the client held its connect lock. Changes that arrive while the client connects, or starts a new session, are now announced once the lock is released. Changes from a connection that failed are not announced.

Tests: two new examples in `spec/ruby_llm/mcp/client_spec.rb` fail on main. The MCP specs pass.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-apply-configured-price-audio-tokens 'Apply a configured price to audio tokens' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A configured input price is ignored without notice by a transcription, when the model lists an audio price.

```ruby
RubyLLM.configure { |config| config.price 'gemini-2.5-flash', provider: :gemini, input: 0.01 }

RubyLLM.transcribe('meeting.wav', model: 'gemini-2.5-flash', provider: :gemini).cost.input
# main:     the list price for audio
# expected: the input tokens at $0.01 per million
```

`input` and `output` now replace the audio token prices too, and the RDoc and the cost guide say so. Limit: one price covers text and audio, as setting them apart would need new API.

Tests: `ruby_llm/configuration_price_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-fetch-embed-moderate-media-context 'Fetch embedded and moderated media with the context' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

`embed` and `moderate` fetch a URL with the global settings, not those of the context they run in. `embed` also downloads it twice.

```ruby
context = RubyLLM.context { |config| config.http_proxy = 'http://proxy.example:8080' }

context.embed(nil, with: 'https://example.com/image', model: 'gemini-embedding-2', provider: :gemini)
# main:     two downloads, the first without the proxy
# expected: one download, through the proxy
```

Attachments are wrapped once, with the configuration of the context. It matters for URLs without an extension, which are fetched to find their type. It is the sibling of #1192.

Tests: `ruby_llm/context_connection_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-inherit-an-agents-description "Inherit an agent's description" <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A subclass inherits every macro of its agent except `description`, so as a tool it has a generic text.

```ruby
class FlightAgent < RubyLLM::Agent
  description "Researches flights"
end
class CharterAgent < FlightAgent; end

CharterAgent.to_tool.description
# main: "Hands a task to the Charter agent, which reports back."
# expected: "Researches flights"
```

`description` is now copied to subclasses like the other macros. `description` of a subclass still replaces it.

Tests: a spec that fails on main, and the spec files around it, with recorded cassettes replayed and nothing live.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-keep-minimax-video-chats-on-messages 'Keep MiniMax chats with a video on Messages' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A MiniMax chat that holds a video raises as soon as web search is on, even when the video came in an earlier turn.

```ruby
chat = RubyLLM.chat(model: 'MiniMax-M3', provider: :minimax)
chat.ask('What is this?', with: 'clip.mp4') # works
chat.with_provider_tools(:web_search).ask('Who made it?')
# main:     RubyLLM::UnsupportedAttachmentError (video/mp4)
# expected: the question goes to Messages, which reads the video and can search
```

Web search moves a chat to MiniMax's Responses route, which carries no video. PDFs already keep a chat on Messages; videos now do too.

Not exercised live.

Tests: `minimax_spec.rb`, including its cassettes.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-keep-chat-model-when-new-one-unknown "Keep a chat's model when the new one is unknown" <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A chat record whose `with_model` fails stays on the model that could not be found.

```ruby
chat = Chat.create!(model: "gpt-4.1-nano")

begin
  chat.with_model("no-such-model")
rescue RubyLLM::ModelNotFoundError
end

chat.ask("Hello")
# main:     RubyLLM::ModelNotFoundError, on every request until the record is reloaded
# expected: asks gpt-4.1-nano, as a plain chat does
```

`with_model` assigned the new model, provider and protocol before resolving them. They are now put back when the model cannot be resolved, and the error is still raised.

Tests: the Active Record specs; no live requests.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-keep-citations-when-a-paused-turn-ends 'Keep citations when a paused turn ends in text' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

When Claude pauses a web search turn (`pause_turn`) and the continuation holds only text, replaying the turn loses that text's citations.

```ruby
chat = RubyLLM.chat(model: 'claude-haiku-4-5').with_provider_tools(:web_search)
chat.ask('Research this') # pauses once, then answers with cited text
chat.ask('Thanks')
# main replays: ..., { type: "text", text: "two" }
# expected:     ..., { "type" => "text", "text" => "two", "citations" => [...] }
```

The segments join into one message. One without a server tool block kept no native blocks, so it was rendered again without citations, with Symbol keys among the provider's String keys. A continuation now keeps its own blocks, streamed or plain.

Not exercised live.

Tests: the Anthropic specs and the provider tool and citation specs, including cassettes.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-keep-decline-notes-when-a-tool-returns-a-task 'Keep decline notes when a tool returns a task' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

When a person declines a question with a note, the model hears the note in the tool result, unless the tool goes on to return a task. Then the note is lost.

```ruby
class Ship < RubyLLM::Tool
  def execute
    ask("Use express?", choices: %w[yes no])
    RubyLLM::Task.new
  end

  def resume(task, **) = "Shipped"
end

chat.ask("Ship it")
chat.pending_questions.first.decline("too expensive")
2.times { chat.complete }
# main: result is "Shipped"
# expected: "Shipped\n\nThe user declined: too expensive"
```

The notes of declined questions are now kept with a call that pauses again, and added to its result.

Tests: a spec that fails on main, and the spec files around it, with recorded cassettes replayed and nothing live.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-keep-queued-messages-a-timeout-stops-from-joining 'Keep queued messages a timeout stops from joining' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A timeout, or a stopped Async task, while queued messages join the conversation deletes them. They leave the queue together, and only a `StandardError` put them back.

```ruby
chat.around_join { |queued, join| slow_check(queued); join.call }
3.times { |i| chat.queue("message #{i}") }
Timeout.timeout(1) { chat.complete } # runs out during the second message
chat.queued_messages.map(&:content)
# main: []
# expected: ["message 1", "message 2"]
```

Messages are now put back in an `ensure`, and a message a callback had joined before it was stopped leaves the conversation again, so it is never in both places. This covers the in-memory queue.

Tests: a spec that fails on main, and the spec files around it, with recorded cassettes replayed and nothing live.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-keep-streamed-converse-server-tool-input 'Keep streamed input of Converse server tool calls' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

When Bedrock Converse streams a tool it runs itself, such as Nova's code interpreter, the call arrives without its input. A plain answer has it.

```ruby
message = chat.ask('What is 1 + 1?') { |chunk| print chunk.content }
message.server_tool_calls.first.input
# main:     nil
# expected: { "snippet" => "1+1" }
```

The stream skips the input deltas of these blocks so they are not taken for function arguments. It now collects them apart and yields the call again with its input when the block stops; the accumulator already replaces a server tool call that repeats its id.

Limits: the event shape follows the AWS reference (https://docs.aws.amazon.com/bedrock/latest/APIReference/API_runtime_ContentBlockDelta.html) and was not exercised live. `toolResult` deltas, which that page also lists, are still not collected.

Tests: the Converse, Bedrock and provider tool specs, including cassettes.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-keep-thinking-inside-output 'Keep thinking inside output above long context' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

Above the long-context threshold, thinking already counted in output is charged a second time.

```ruby
# google/gemini-2.5-pro on OpenRouter
tokens = RubyLLM::Tokens.new(input: 200_001, output: 10_000, thinking: 6_000)

model.cost_for(tokens).thinking
# main:     0.09
# expected: nil, it is inside output (0.15)
```

The long-context tier has no thinking price, so the standard one was compared with the higher output price and looked separate. Only prices of the same tier are compared now.

Tests: `ruby_llm/cost_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-list-only-the-named-folder 'List only the named folder of chat files on SQLite' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

On SQLite, listing a folder of a chat's files also returns a folder that differs only in case.

```ruby
store = chat.with_file_store.file_store
store.write("results/a.txt", "a")
store.write("Results/b.txt", "b")

store.list("results").map(&:path)
# main, SQLite:                 ["Results/b.txt", "results/a.txt"]
# main, PostgreSQL and :memory: ["results/a.txt"]
```

SQLite's `LIKE` ignores case. `list` now goes through `rows_in_folder`, the helper `delete_folder` already uses, which checks each path in Ruby.

Tests: the file store specs; no live requests. I ran this on SQLite only.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-raise-on-truncated-voxtral-transcript 'Raise on a truncated Bedrock Voxtral transcript' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A Bedrock Voxtral transcript that reaches its output token limit comes back as a complete transcript. The same call with a block raises.

```ruby
RubyLLM.transcribe('meeting.wav', model: 'mistral.voxtral-mini-3b-2507', provider: :bedrock,
                   provider_options: { max_tokens: 20 })
# main:     a Transcription whose text stops mid-sentence
# expected: RubyLLM::Error, "Bedrock Voxtral did not complete the transcript"
```

The plain call ignored `finish_reason`. It now raises the error the streamed call raises, unless the reason is `stop` or missing, and records the tokens as a failed attempt.

Not exercised live.

Tests: the Bedrock Mantle specs, including cassettes.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-read-nonbreaking-hyphens-word 'Read non-breaking hyphens in Word documents' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

`read_file` drops non-breaking hyphens from Word documents, which changes phone numbers and ranges.

```ruby
# a .docx with 555-1234, typed with a non-breaking hyphen
# read_file shows
# main:     5551234
# expected: 555-1234
```

Word stores the hyphen as an element of its own. It is read as a hyphen.

Tests: `ruby_llm/file_store/converters/office_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-report-bedrock-row-failure-reason 'Report the reason a Bedrock batch row failed' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

When a row of a Bedrock batch fails, the warning does not say why, and it is the one trace of the reason.

```ruby
# one row of the batch output
# { "recordId": "3", "error": { "errorCode": 400, "errorMessage": "bad input" } }

# main:     the warning has no reason
# expected: Batch request 3 failed: bad input
```

It reads `error.errorMessage`, [where AWS puts the reason](https://docs.aws.amazon.com/bedrock/latest/userguide/batch-inference-results.html), for chat and embedding batches. This rests on the documentation and was not exercised live.

Tests: `ruby_llm/protocols/converse/batches_spec.rb`, `ruby_llm/protocols/invoke_model/embedding_batches_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-shorten-long-attachment-names 'Shorten long names of stored attachments' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A long attachment name raises from the `Directory` store, because file systems limit a name to 255 bytes. 90 Japanese characters are enough.

```ruby
attachment = RubyLLM::Attachment.new(StringIO.new('x'), filename: "#{'日' * 90}.txt")

RubyLLM::FileStore::Directory.new('workspace').store_attachment(attachment).path
# main:     Errno::ENAMETOOLONG
# expected: 83 characters and ".txt"
```

The name is cut by bytes and keeps its extension and its number when the name is taken. It applies to every store, so a file keeps one name wherever it is stored.

Tests: `ruby_llm/file_store/directory_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-sit-out-an-mcp-server-whose-command-is-missing 'Sit out an MCP server whose command is missing' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A stdio MCP server whose command is not installed, such as `npx` missing from a production image, crashes the chat with an error no RubyLLM rescue sees. A server that starts and exits right away only sits out.

```ruby
class Files < RubyLLM::MCP
  command "npx", "-y", "@modelcontextprotocol/server-filesystem", "/data"
end

RubyLLM.chat.with_mcp(Files.new).ask("Hello") # npx is not installed
# main: Errno::ENOENT
# expected: the chat answers without the server's tools, and the log says it is unreachable
```

Starting the process now turns a system error into `Stdio::Unavailable`, which sits the server out. A missing working directory is covered too. Calling the server directly raises that error, naming the command. Code that rescues `Errno::ENOENT` there no longer sees it, though it is the `cause`.

Tests: two new examples in `spec/ruby_llm/mcp/stdio_spec.rb` fail on main. The MCP and outage specs pass.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-split-cached-input-gemini-transcriptions 'Split cached input out of Gemini transcriptions' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

A Gemini transcription charges cached tokens at the full input price and leaves `cache_read` empty.

```ruby
# Gemini reports promptTokenCount: 1000, cachedContentTokenCount: 900

transcription.tokens.input       # main: 1000   expected: 100
transcription.tokens.cache_read  # main: nil    expected: 900
```

`promptTokenCount` includes cached tokens. They are split out as chat does, on Gemini and Vertex AI. Speech and Live transcription are left alone.

Tests: `ruby_llm/protocols/gemini/transcription_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr low claude/fix-stop-reading-elapsed-times-dates 'Stop reading elapsed times as dates' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
Requested by **Kieran**

## What this does

`read_file` shows an elapsed time in a spreadsheet as a date.

```ruby
# a cell holding 36 hours (1.5), with built-in number format 46, [h]:mm:ss
# read_file shows
# main:     1900-01-01 12:00:00
# expected: 1.5
```

Format 46 is no longer read as a date. Custom formats of that shape were already left as numbers.

Tests: `ruby_llm/file_store/converters/office_spec.rb`.

## Type of change

- [x] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

<!-- Optional. Fixes #___ -->

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [x] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
