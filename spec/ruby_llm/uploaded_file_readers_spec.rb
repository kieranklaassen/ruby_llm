# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::UploadedFile do
  describe '#raw' do
    it 'returns the provider response' do
      file = described_class.new(id: 'file_123', raw: { 'object' => 'file' })

      expect(file.raw).to eq('object' => 'file')
    end

    it 'defaults to an empty Hash' do
      expect(described_class.new(id: 'file_123').raw).to eq({})
    end
  end

  describe '#metadata' do
    it 'returns #raw with a deprecation warning' do
      allow(RubyLLM.deprecator).to receive(:warn)
      file = described_class.new(id: 'file_123', raw: { 'object' => 'file' })

      expect(file.metadata).to eq('object' => 'file')
      expect(RubyLLM.deprecator).to have_received(:warn)
        .with('UploadedFile#metadata is deprecated and will be removed in RubyLLM 3.0. Use UploadedFile#raw instead.')
    end
  end
end
