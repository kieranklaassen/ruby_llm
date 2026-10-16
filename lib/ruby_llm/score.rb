# frozen_string_literal: true

module RubyLLM
  # A probability-weighted position on a judgment's ordered levels.
  class Score
    include Support::Inspectable

    # The weighted score, which can fall between level indexes.
    attr_reader :score

    # The ordered descriptions, preserving structured Hashes and Arrays.
    attr_reader :levels

    # Each zero-based Integer level index's probability.
    attr_reader :probabilities

    # The provider's confidence in the distribution, between 0 and 1.
    attr_reader :confidence

    def initialize(score:, levels:, probabilities:, confidence:) # :nodoc:
      @score = score
      @levels = Judge::Data.copy(levels)
      @probabilities = probabilities.dup.freeze
      @confidence = confidence
      freeze
    end

    # Returns +:score+.
    def type
      :score
    end

    # Returns the answer as a Hash.
    def to_h
      { type:, score:, levels:, probabilities:, confidence: }
    end

    private

    def inspect_attributes # :nodoc:
      { score:, confidence: }
    end
  end
end
