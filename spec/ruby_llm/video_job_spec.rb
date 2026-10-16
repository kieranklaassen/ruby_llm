# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::VideoJob do
  let(:config) { RubyLLM::Configuration.new }
  let(:protocol) do
    instance_double(RubyLLM::Protocols::Gemini, config:,
                                                provider: instance_double(RubyLLM::Providers::Gemini, slug: 'gemini'))
  end

  describe '#provider' do
    it 'returns the provider slug as a String' do
      expect(described_class.new(id: 'operations/op-1', protocol:).provider).to eq('gemini')
    end
  end

  describe 'RubyLLM::Video.animate' do
    it 'passes timeout: and interval: to the wait' do
      job = described_class.new(id: 'operations/op-1', protocol:, model: 'veo')
      video = RubyLLM::Video.new(url: 'https://example.com/clip.mp4', model: 'veo')
      allow(described_class).to receive(:animate_later).and_return(job)
      allow(job).to receive_messages(wait: job, video: video)

      expect(RubyLLM::Video.animate('A rocket launch', timeout: 900, interval: 10)).to be(video)
      expect(job).to have_received(:wait).with(timeout: 900, interval: 10)
    end
  end
end
