module LLM
  class BaseProvider
    # Abstract method to generate a response from the LLM
    # @param prompt [String] the user's prompt
    # @param context [Hash] optional context data to enhance the prompt
    # @param options [Hash] provider-specific options
    # @return [String] the LLM's response
    def generate_response(prompt, context: {}, options: {})
      raise NotImplementedError, "Subclasses must implement #generate_response"
    end

    # Abstract method to generate a streaming response from the LLM
    # @param prompt [String] the user's prompt
    # @param context [Hash] optional context data to enhance the prompt
    # @param options [Hash] provider-specific options
    # @yield [String] yields each chunk of the response as it's generated
    # @return [void]
    def generate_streaming_response(prompt, context: {}, options: {}, &block)
      raise NotImplementedError, "Subclasses must implement #generate_streaming_response"
    end

    # Abstract method to get available models from the provider
    # @return [Array<String>] list of available model names
    def available_models
      raise NotImplementedError, "Subclasses must implement #available_models"
    end

    # Abstract method to check if the provider is available/reachable
    # @return [Boolean] true if the provider is available
    def available?
      raise NotImplementedError, "Subclasses must implement #available?"
    end

    # Formats context data into a string the LLM can use
    # @param context [Hash] context data
    # @return [String] formatted context
    def format_context(context)
      return "" if context.blank?

      result = "Here is some context that might help you:\n\n"
      
      context.each do |key, value|
        result += "## #{key.to_s.titleize}\n"
        result += value.to_s
        result += "\n\n"
      end
      
      result
    end

    # Builds a complete prompt with context
    # @param prompt [String] the user's prompt
    # @param context [Hash] context data
    # @return [String] the full prompt with context
    def build_prompt(prompt, context)
      context_str = format_context(context)
      if context_str.present?
        "#{context_str}\n\nUser query: #{prompt}"
      else
        prompt
      end
    end
  end
end