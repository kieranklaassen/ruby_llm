# frozen_string_literal: true

module RubyLLM
  # Represents a conversation with an AI model. Handles message history,
  # streaming responses, and tool integration with a simple, conversational API.
  #
  # Example:
  #   chat = RubyLLM.chat
  #   chat.ask "What's the best way to learn Ruby?"
  #   chat.ask "Can you elaborate on that?"
  class Chat
    include Enumerable

    attr_reader :model, :messages, :tools, :response_format, :parser

    def initialize(model: nil, provider: nil)
      model_id = model || RubyLLM.config.default_model
      with_model(model_id, provider: provider)
      @temperature = 0.7
      @messages = []
      @tools = {}
      @on = {
        new_message: nil,
        end_message: nil
      }
      @response_format = nil
      @parser = :text  # Default to text parser
    end

    def ask(message = nil, with: {}, &block)
      add_message role: :user, content: Content.new(message, with)
      complete(&block)
    end

    alias say ask

    def with_tool(tool)
      unless @model.supports_functions
        raise UnsupportedFunctionsError, "Model #{@model.id} doesn't support function calling"
      end

      tool_instance = tool.is_a?(Class) ? tool.new : tool
      @tools[tool_instance.name.to_sym] = tool_instance
      self
    end

    def with_tools(*tools)
      tools.each { |tool| with_tool tool }
      self
    end

    def with_model(model_id, provider: nil)
      @model = Models.find model_id, provider
      @provider = Provider.providers[@model.provider.to_sym] || raise(Error, "Unknown provider: #{@model.provider}")
      self
    end

    def with_temperature(temperature)
      @temperature = temperature
      self
    end

    # Sets a response format for the model to use when generating responses.
    # This enforces structured output according to the provided schema.
    #
    # @param format [Class, Hash, String] Format can be:
    #   - A class that responds to .json_schema (Plain Old Ruby Object)
    #   - A hash representing a JSON schema
    #   - A string containing a valid JSON schema
    # @return [Chat] Returns self for method chaining
    # @example Using a class
    #   chat.with_response_format(Delivery)
    # @example Using a hash
    #   chat.with_response_format({type: "object", properties: {name: {type: "string"}}})
    def with_response_format(format)
      @response_format = format
      @parser = :json
      self
    end

    # Sets a custom parser to use for processing model responses
    #
    # @param parser_type [Symbol] The registered parser type to use
    # @param options [Hash] Additional options to pass to the parser
    # @return [Chat] Returns self for method chaining
    # @example Using XML parser to extract specific tag
    #   chat.with_parser(:xml, tag: 'result')
    # @example Using default JSON parser
    #   chat.with_parser(:json)
    def with_parser(parser_type, options = nil)
      if !ResponseParser.parsers.key?(parser_type.to_sym)
        raise Error, "Unknown parser type: #{parser_type}. Available parsers: #{ResponseParser.parsers.keys.join(', ')}"
      end

      @parser = parser_type.to_sym
      @parser_options = options
      self
    end

    def on_new_message(&block)
      @on[:new_message] = block
      self
    end

    def on_end_message(&block)
      @on[:end_message] = block
      self
    end

    def each(&)
      messages.each(&)
    end

    def complete(&)
      @on[:new_message]&.call

      # Get raw response from provider
      response = @provider.complete(
        messages,
        tools: @tools,
        temperature: @temperature,
        model: @model.id,
        response_format: @response_format,
        &
      )

      @on[:end_message]&.call(response)

      # Apply appropriate parser - use response_format if present, or specified parser
      format_or_parser = @response_format || (@parser_options || @parser)
      parsed_response = ResponseParser.parse(response, format_or_parser)

      # Add the parsed response to messages
      add_message parsed_response

      if parsed_response.tool_call?
        handle_tool_calls(parsed_response, &)
      else
        parsed_response
      end
    end

    def add_message(message_or_attributes)
      message = message_or_attributes.is_a?(Message) ? message_or_attributes : Message.new(message_or_attributes)
      messages << message
      message
    end

    private

    def handle_tool_calls(response, &)
      response.tool_calls.each_value do |tool_call|
        @on[:new_message]&.call
        result = execute_tool tool_call
        message = add_tool_result tool_call.id, result
        @on[:end_message]&.call(message)
      end

      complete(&)
    end

    def execute_tool(tool_call)
      tool = tools[tool_call.name.to_sym]
      args = tool_call.arguments
      tool.call(args)
    end

    def add_tool_result(tool_use_id, result)
      add_message(
        role: :tool,
        content: result.is_a?(Hash) && result[:error] ? result[:error] : result.to_s,
        tool_call_id: tool_use_id
      )
    end
  end
end
