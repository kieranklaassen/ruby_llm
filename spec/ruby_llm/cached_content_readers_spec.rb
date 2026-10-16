# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::CachedContent do
  let(:data) { { 'name' => 'cachedContents/abc123', 'usageMetadata' => { 'totalTokenCount' => 7809 } } }

  describe '#raw' do
    it 'returns the provider response' do
      expect(described_class.new(id: 'cachedContents/abc123', raw: data).raw).to eq(data)
    end

    it 'defaults to an empty Hash' do
      expect(described_class.new(id: 'cachedContents/abc123').raw).to eq({})
    end

    it 'follows the provider response after a renewal' do
      renewed = described_class.new(id: 'cachedContents/abc123', expires_at: Time.at(600),
                                    raw: data.merge('expireTime' => 'later'))
      provider = instance_double(RubyLLM::Providers::Gemini, slug: 'gemini', extend_cache: renewed)
      cache = described_class.new(id: 'cachedContents/abc123', provider_instance: provider, raw: data)

      cache.renew(ttl: 600)

      expect(cache).to have_attributes(raw: renewed.raw, expires_at: Time.at(600))
    end
  end

  describe '#id' do
    it 'returns the provider id' do
      expect(described_class.new(id: 'cachedContents/abc123').id).to eq('cachedContents/abc123')
    end
  end

  describe '#name' do
    it 'returns #id with a deprecation warning' do
      allow(RubyLLM.deprecator).to receive(:warn)
      cache = described_class.new(id: 'cachedContents/abc123')

      expect(cache.name).to eq('cachedContents/abc123')
      expect(RubyLLM.deprecator).to have_received(:warn)
        .with('CachedContent#name is deprecated and will be removed in RubyLLM 3.0. Use CachedContent#id instead.')
    end
  end

  describe '#metadata' do
    it 'returns #raw with a deprecation warning' do
      allow(RubyLLM.deprecator).to receive(:warn)
      cache = described_class.new(id: 'cachedContents/abc123', raw: data)

      expect(cache.metadata).to eq(data)
      expect(RubyLLM.deprecator).to have_received(:warn)
        .with('CachedContent#metadata is deprecated and will be removed in RubyLLM 3.0. Use CachedContent#raw instead.')
    end
  end
end
