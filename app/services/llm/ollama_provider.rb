require 'ollama-ai'
require 'net/http'
require 'uri'

module LLM
  class OllamaProvider < BaseProvider
    attr_reader :client, :model

    def initialize(model: nil)
      host = Rails.configuration.llm.ollama_url
      @client = Ollama::Client.new(host: host)
      @model = model || Rails.configuration.llm.ollama_default_model
    end

    def generate_response(prompt, context: {}, options: {})
      full_prompt = build_prompt(prompt, context)
      response = client.generate(
        model: model,
        prompt: full_prompt,
        options: options
      )
      response.output
    rescue => e
      Rails.logger.error("Ollama LLM error: #{e.message}")
      "Sorry, I encountered an error while processing your request."
    end

    def generate_streaming_response(prompt, context: {}, options: {}, &block)
      full_prompt = build_prompt(prompt, context)
      client.generate_stream(
        model: model,
        prompt: full_prompt,
        options: options
      ) do |chunk|
        yield chunk.output if block_given?
      end
    rescue => e
      Rails.logger.error("Ollama LLM streaming error: #{e.message}")
      yield "Sorry, I encountered an error while processing your request." if block_given?
    end

    def available_models
      begin
        models = client.list.models.map(&:name)
        return models if models.any?
      rescue => e
        Rails.logger.error("Ollama available_models error: #{e.message}")
      end
      
      # Fallback to default model if we couldn't get models
      Rails.logger.info("Using default Ollama model as fallback")
      [Rails.configuration.llm.ollama_default_model]
    end

    def available?
      begin
        client.list.models.any?
      rescue => e
        Rails.logger.error("Ollama availability check error: #{e.message}")
        
        # Let's check if Ollama is running by making a simple request directly
        begin
          host_uri = URI.parse(Rails.configuration.llm.ollama_url)
          http = Net::HTTP.new(host_uri.host, host_uri.port)
          http.read_timeout = 5
          http.open_timeout = 5
          response = http.get('/api/version')
          return response.code.to_i == 200
        rescue => e2
          Rails.logger.error("Secondary Ollama availability check error: #{e2.message}")
          return false
        end
      end
    end
  end
end