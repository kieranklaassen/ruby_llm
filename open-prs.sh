#!/usr/bin/env bash
# Opens pull requests on crmne/ruby_llm from branches on kieranklaassen/ruby_llm.
# Safe to rerun: skips branches that already have a pull request.
set -u
open_pr() {
  n=$(gh pr list --repo crmne/ruby_llm --state all --head "$1" --author kieranklaassen --json number --jq '.[0].number')
  if [ -n "$n" ]; then echo "exists #$n $1"; cat >/dev/null; return 0; fi
  f=$(mktemp); cat > "$f"
  gh pr create --repo crmne/ruby_llm --base main --head "kieranklaassen:$1" --title "$2" --body-file "$f" || echo "FAILED $1"
  rm -f "$f"; sleep 20
}
open_pr claude/improve-rebuild-messages-without-content 'Rebuild a message that has no content' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
_Requested by **Kieran**_

## What this does

Message#to_h leaves out a nil content, as it does for every nil value, but Message.new then required the key. Rebuilding such a message, for example a user message that only carries attachments, raised a KeyError. Targeted specs, RuboCop, archspec, Flay, and `rake api:check` pass. The new spec fails without the change.

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

None.

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [ ] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr claude/improve-string-provider-options 'Merge provider options that have String keys' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
_Requested by **Kieran**_

## What this does

Options with String keys, such as ones loaded from JSON or YAML, sat beside the Symbol keys of the request instead of merging into them. The JSON then carried the same key twice, and with_provider_options on a nested section dropped what RubyLLM had put there. Targeted specs, RuboCop, archspec, Flay, and `rake api:check` pass. The new spec fails without the change.

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

None.

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [ ] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr claude/improve-encode-lone-percent 'Encode a bare percent sign in MCP resource URIs' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
_Requested by **Kieran**_

## What this does

{+var} and {#var} keep percent-encoded triplets as they are, but every other percent sign has to be encoded (RFC 6570, section 3.2.1). A value such as "50% off" expanded to "50%%20off", which is not a valid URI. Targeted specs, RuboCop, archspec, Flay, and `rake api:check` pass. The new spec fails without the change.

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

None.

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [ ] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr claude/improve-empty-path-parameters 'Expand an empty path parameter to its name alone' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
_Requested by **Kieran**_

## What this does

RFC 6570 expands {;lang} with an empty value to ";lang", while {?lang} keeps its equals sign. RubyLLM wrote ";lang=" for both. Targeted specs, RuboCop, archspec, Flay, and `rake api:check` pass. The new spec fails without the change.

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

None.

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [ ] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr claude/improve-destroy-mcp-by-name 'Destroy a generated MCP server by its name' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
_Requested by **Kieran**_

## What this does

bin/rails destroy ruby_llm:mcp NAME failed because the check for a URL or a command also ran on destroy, where neither is needed. Targeted specs, RuboCop, archspec, Flay, and `rake api:check` pass. The generator specs pass with the change.

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

None.

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [ ] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr claude/improve-destroy-skill-by-name 'Destroy a generated skill by its name' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
_Requested by **Kieran**_

## What this does

bin/rails destroy ruby_llm:skill NAME failed because the description was a required argument, and the check of the skill ran on destroy too. The name is enough to remove what the generator created. Targeted specs, RuboCop, archspec, Flay, and `rake api:check` pass. The generator specs pass with the change.

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

None.

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [ ] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr claude/improve-remove-rtf-document-type 'Remove RTF from the document MIME types' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
_Requested by **Kieran**_

## What this does

MimeType.document? returns false for every text type before it reads the list, and application/rtf is a text type, so the entry never matched. No behavior changes. Targeted specs, RuboCop, archspec, Flay, and `rake api:check` pass.

## Type of change

- [ ] Bug fix
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

None.

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [ ] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr claude/improve-remove-unit-columns 'Remove the unused Usage::UNIT_COLUMNS' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
_Requested by **Kieran**_

## What this does

Nothing reads the constant. The usage record builds its unit columns from Cost::UNITS where it needs them. No behavior changes. Targeted specs, RuboCop, archspec, Flay, and `rake api:check` pass.

## Type of change

- [ ] Bug fix
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

None.

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [ ] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr claude/improve-loop-provider-metadata 'Loop over the fields a provider fills in' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
_Requested by **Kieran**_

## What this does

Registry merging repeated the same conditional assignment for six fields, which also needed a disabled complexity cop. No behavior changes. Targeted specs, RuboCop, archspec, Flay, and `rake api:check` pass.

## Type of change

- [ ] Bug fix
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

None.

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [ ] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr claude/improve-simplify-streaming-error-lookup 'Simplify the lookup of a stored stream error' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
_Requested by **Kieran**_

## What this does

The middleware always passes an environment or a response that takes [], so neither the respond_to? check nor the rescued NameError, which would also have hidden real mistakes, has a case to handle. No behavior changes. Targeted specs, RuboCop, archspec, Flay, and `rake api:check` pass.

## Type of change

- [ ] Bug fix
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

None.

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [x] I tested my changes thoroughly
  - [ ] For provider changes: Re-recorded VCR cassettes with `bundle exec rake vcr:record[provider_name]`
  - [ ] All tests pass: `bundle exec rspec`
- [ ] I updated documentation if needed
- [x] I didn't modify auto-generated files manually (`models.json`, `aliases.json`)

## Ownership

- [ ] I understand every line of this change and can answer questions about it

## API changes

- [ ] Breaking change
- [ ] New public methods/classes
- [ ] Changed method signatures
- [x] No API changes
PRBODYEND
open_pr claude/improve-docs-batch-request-counts 'Document Batch#request_counts' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
_Requested by **Kieran**_

## What this does

The batches guide covers status and complete? but not the tallies a provider reports while a batch runs.

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [x] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

None.

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [ ] I tested my changes thoroughly
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
open_pr claude/improve-docs-context-operations 'List every operation a context offers' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
_Requested by **Kieran**_

## What this does

The guide left out chat, count_tokens, tokenize, judge, research, research_later, and workflow.

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [x] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

None.

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [ ] I tested my changes thoroughly
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
open_pr claude/improve-docs-cost-rdoc 'Tidy the class documentation of Cost' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
_Requested by **Kieran**_

## What this does

Two blank lines split the overview, and a sentence about the class methods ran on from an unrelated one.

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [x] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

None.

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [ ] I tested my changes thoroughly
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
open_pr claude/improve-docs-error-code-example 'Read the error code in the forbidden error example' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
_Requested by **Kieran**_

## What this does

RubyLLM parses JSON bodies, so response.body is a Hash there and include? looked for a top-level key. error_code has the provider's code.

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [x] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

None.

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [ ] I tested my changes thoroughly
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
open_pr claude/improve-docs-expired-files 'Document UploadedFile#expired?' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
_Requested by **Kieran**_

## What this does

The files guide shows expires_at but not the predicate that tells whether a stored file can still serve a request.

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [x] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

None.

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [ ] I tested my changes thoroughly
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
open_pr claude/improve-docs-image-audio-models 'List the image and audio model filters' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
_Requested by **Kieran**_

## What this does

The registry guide showed chat_models and embedding_models but not the other two filters.

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [x] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

None.

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [ ] I tested my changes thoroughly
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
open_pr claude/improve-docs-input-required-error 'List InputRequiredError in the error guide' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
_Requested by **Kieran**_

## What this does

It inherits from RubyLLM::Error like the other classes in the table, but the guide never mentioned it.

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [x] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

None.

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [ ] I tested my changes thoroughly
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
open_pr claude/improve-docs-nil-stream-chunks 'Handle nil chunks in the streaming error example' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
_Requested by **Kieran**_

## What this does

A chunk that only carries thinking or a tool call has nil content, so the example raised a TypeError when it appended it to a String.

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [x] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

None.

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [ ] I tested my changes thoroughly
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
open_pr claude/improve-docs-retry-after-ms 'Mention retry-after-ms where retries are configured' <<'PRBODYEND'
<!-- claude-projects-attribution: {"github_login":"kieranklaassen"} -->
_Requested by **Kieran**_

## What this does

RubyLLM honors the header, and the error guide says so, but the connection settings list left it out.

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [x] Documentation
- [ ] Performance improvement

## Scope check

- [x] I read the [Contributing Guide](https://github.com/crmne/ruby_llm/blob/main/CONTRIBUTING.md)
- [x] This aligns with RubyLLM's focus on **LLM communication**
- [x] This isn't application-specific logic that belongs in user code
- [x] This benefits most users, not just my specific use case

## Related issue

None.

## Quality check

- [ ] I ran `overcommit --install` and all hooks pass
- [ ] I tested my changes thoroughly
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
