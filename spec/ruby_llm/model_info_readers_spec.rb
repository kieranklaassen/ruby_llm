# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'model_info on operation results' do # rubocop:disable RSpec/DescribeClass
  let(:model) { model_for(:openai) }
  let(:results) do
    lambda do |id|
      [
        RubyLLM::Judgment.new(answers: {}, model: id),
        RubyLLM::Moderation.new(id: 'modr-1', model: id, results: []),
        RubyLLM::OCR.new(pages: [], model: id),
        RubyLLM::Tokenization.new(ids: [1], model: id),
        RubyLLM::Video.new(url: 'https://example.com/clip.mp4', model: id)
      ]
    end
  end

  it 'returns the Model of the result' do
    expect(results.call(model).map(&:model_info)).to all(be_a(RubyLLM::Model).and(have_attributes(id: model)))
  end

  it 'returns nil when the model is unknown' do
    expect(results.call('no-such-model-exists').map(&:model_info)).to all(be_nil)
  end

  it 'returns nil for a result without a model' do
    moderation = RubyLLM::Moderation.new(id: 'modr-1', model: nil, results: [])

    expect([moderation.model_info, RubyLLM::Video.new(url: 'https://example.com/clip.mp4').model_info]).to all(be_nil)
  end
end
