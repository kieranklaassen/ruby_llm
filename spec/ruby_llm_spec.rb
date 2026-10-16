# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM do
  describe '.count_tokens' do
    it 'forwards assume_model_exists and context to the chat' do
      context = described_class.context
      chat = instance_double(RubyLLM::Chat, count_tokens: 12)
      allow(RubyLLM::Chat).to receive(:new)
        .with(model: 'model', provider: :openai, assume_model_exists: true, context:)
        .and_return(chat)

      count = described_class.count_tokens('Hello', model: 'model', provider: :openai,
                                                    assume_model_exists: true, context:)

      expect(count).to eq(12)
    end
  end

  describe '.embed_later' do
    include_context 'with configured RubyLLM'

    it 'stages a request for a model missing from the registry' do
      request = described_class.embed_later('Hello', model: 'my-custom-embedder', provider: :openai,
                                                     assume_model_exists: true)

      expect(request.model.id).to eq('my-custom-embedder')
    end

    it 'resolves the provider with the context configuration' do
      context = described_class.context { |config| config.request_timeout = 7 }

      request = described_class.embed_later('Hello', model: model_for(:openai, :embedding), context:)

      expect(request.provider.config).to be(context.config)
    end
  end

  describe '.logger' do
    let(:logger) { instance_double(Logger) }
    let(:log_file) { double }
    let(:log_level) { double }

    around do |example|
      original_config = described_class.instance_variable_get(:@config)
      original_logger = described_class.instance_variable_get(:@logger)
      described_class.instance_variable_set(:@config, nil)
      described_class.instance_variable_set(:@logger, nil)
      example.run
    ensure
      described_class.instance_variable_set(:@config, original_config)
      described_class.instance_variable_set(:@logger, original_logger)
    end

    context 'with configuration options' do
      before do
        described_class.configure do |config|
          config.log_file = log_file
          config.log_level = log_level
        end
      end

      it 'returns a default Logger' do
        allow(Logger).to receive(:new).with(log_file, progname: 'RubyLLM', level: log_level).and_return(logger)

        expect(described_class.logger).to eq(logger)
      end
    end

    context 'with a custom logger' do
      before do
        described_class.configure do |config|
          config.logger = logger
          config.log_file = log_file
          config.log_level = log_level
        end
      end

      it 'returns a the custom Logger' do
        expect(described_class.logger).to eq(logger)
      end
    end
  end
end
