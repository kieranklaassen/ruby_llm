# frozen_string_literal: true

module RubyLLM
  # A TranscriptionChunk is one event from a streaming transcription.
  # RubyLLM.transcribe yields these to its block as the provider transcribes
  # the audio, then returns the final Transcription.
  #
  #   RubyLLM.transcribe("meeting.wav", model: "gpt-4o-transcribe") do |chunk|
  #     print chunk.delta if chunk.delta?
  #   end
  #
  class TranscriptionChunk
    include Support::Inspectable

    # The event type: +:delta+ for text arriving as the model transcribes,
    # +:partial+ for a tentative transcript that may still change,
    # +:segment+ for a completed timed or diarized segment, or +:done+ for
    # the final event. Returns +nil+ for an event RubyLLM does not
    # normalize; read it from #raw.
    attr_reader :type

    # The text added by this event, or +nil+ for events that add no text.
    attr_reader :delta

    # The transcript for a partial event or the complete final transcript.
    attr_reader :text

    # The segment this event completed as a Hash, or +nil+. Diarization
    # models label each segment with a speaker.
    attr_reader :segment

    # The parsed provider event, for fields RubyLLM does not normalize.
    attr_reader :raw

    def initialize(type:, delta: nil, text: nil, segment: nil, raw: nil) # :nodoc:
      @type = type
      @delta = delta
      @text = text
      @segment = segment
      @raw = raw
    end

    # Returns whether this event carries a text delta.
    def delta? = !delta.nil?

    # Returns whether this is a tentative transcript, replacing the previous partial.
    def partial? = type == :partial

    # Returns whether this event completed a segment.
    def segment? = !segment.nil?

    # Returns whether this is the final event of the transcription.
    def done? = type == :done

    private

    def inspect_attributes # :nodoc:
      { type: type, delta: delta, text: text, segment: segment }
    end
  end
end
