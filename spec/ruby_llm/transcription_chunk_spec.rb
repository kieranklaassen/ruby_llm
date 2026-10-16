# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::TranscriptionChunk do
  it 'reports partial and final events from its Symbol type' do
    expect(described_class.new(type: :partial, text: 'Hel')).to have_attributes(partial?: true, done?: false)
    expect(described_class.new(type: :done, text: 'Hello')).to have_attributes(partial?: false, done?: true)
  end

  it 'reports deltas and segments from what the event carries' do
    segment = { 'text' => 'Hello', 'speaker' => 'A' }
    chunk = described_class.new(type: :segment, delta: 'Hello', segment:)

    expect(chunk).to have_attributes(delta?: true, segment?: true, done?: false)
    expect(described_class.new(type: :done)).to have_attributes(delta?: false, segment?: false)
  end

  it 'shows its type in one line' do
    expect(described_class.new(type: :delta, delta: 'Hello').inspect)
      .to eq('#<RubyLLM::TranscriptionChunk type: :delta, delta: "Hello">')
  end
end
