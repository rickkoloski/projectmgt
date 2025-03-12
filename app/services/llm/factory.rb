module LLM
  class Factory
    # Get an LLM provider instance based on configuration
    # @param provider [Symbol] The provider to use (:auto, :ollama, :openai)
    # @param model [String] Optional specific model to use
    # @return [LLM::BaseProvider] An instance of the LLM provider
    def self.provider(provider = :auto, model = nil)
      provider = determine_provider if provider == :auto
      
      case provider
      when :ollama
        OllamaProvider.new(model: model)
      when :openai
        OpenAIProvider.new(model: model)
      else
        Rails.logger.error("Unknown LLM provider: #{provider}")
        fallback_provider(model)
      end
    end
    
    # Determine the best available provider based on configuration
    # @return [Symbol] The provider to use
    def self.determine_provider
      preferred = Rails.configuration.llm.preferred_provider.to_sym
      
      case preferred
      when :ollama
        begin
          ollama = OllamaProvider.new
          return :ollama if ollama.available?
        rescue => e
          Rails.logger.error("Error checking Ollama availability: #{e.message}")
        end
      when :openai
        begin
          openai = OpenAIProvider.new
          return :openai if openai.available?
        rescue => e
          Rails.logger.error("Error checking OpenAI availability: #{e.message}")
        end
      end
      
      # Fallback to any available provider
      begin
        ollama = OllamaProvider.new
        return :ollama if ollama.available?
      rescue => e
        Rails.logger.error("Error checking Ollama availability in fallback: #{e.message}")
      end
      
      begin
        openai = OpenAIProvider.new
        return :openai if openai.available?
      rescue => e
        Rails.logger.error("Error checking OpenAI availability in fallback: #{e.message}")
      end
      
      # Last resort
      :ollama
    end
    
    # Get a fallback provider when the requested one is unavailable
    # @param model [String] Optional specific model to use
    # @return [LLM::BaseProvider] A fallback provider instance
    def self.fallback_provider(model = nil)
      Rails.logger.warn("Using fallback LLM provider")
      
      begin
        ollama = OllamaProvider.new(model: model)
        return ollama if ollama.available?
      rescue => e
        Rails.logger.error("Error checking Ollama availability for fallback: #{e.message}")
      end
      
      begin
        openai = OpenAIProvider.new(model: model)
        return openai if openai.available?
      rescue => e
        Rails.logger.error("Error checking OpenAI availability for fallback: #{e.message}")
      end
      
      # Last resort, return Ollama even if it might not work
      OllamaProvider.new(model: model)
    end
  end
end