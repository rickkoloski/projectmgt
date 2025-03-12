require 'openai'

module LLM
  class OpenAIProvider < BaseProvider
    attr_reader :client, :model

    def initialize(model: nil)
      api_key = Rails.application.credentials.openai&.api_key
      @client = OpenAI::Client.new(access_token: api_key)
      @model = model || Rails.configuration.llm.openai_default_model
    end

    def generate_response(prompt, context: {}, options: {})
      full_prompt = build_prompt(prompt, context)
      response = client.chat(
        parameters: {
          model: model,
          messages: [{ role: "user", content: full_prompt }],
          temperature: options[:temperature] || 0.7,
          max_tokens: options[:max_tokens] || 800
        }
      )
      response.dig("choices", 0, "message", "content")
    rescue => e
      Rails.logger.error("OpenAI LLM error: #{e.message}")
      "Sorry, I encountered an error while processing your request."
    end

    def generate_streaming_response(prompt, context: {}, options: {}, &block)
      full_prompt = build_prompt(prompt, context)
      
      client.chat(
        parameters: {
          model: model,
          messages: [{ role: "user", content: full_prompt }],
          temperature: options[:temperature] || 0.7,
          max_tokens: options[:max_tokens] || 800,
          stream: true
        }
      ) do |chunk|
        content = chunk.dig("choices", 0, "delta", "content")
        yield content if content && block_given?
      end
    rescue => e
      Rails.logger.error("OpenAI LLM streaming error: #{e.message}")
      yield "Sorry, I encountered an error while processing your request." if block_given?
    end

    def available_models
      response = client.models
      models = response["data"].map { |m| m["id"] }
      # Filter for models that support chat completion
      models.select { |m| m.include?("gpt") }
    rescue => e
      Rails.logger.error("OpenAI available_models error: #{e.message}")
      []
    end

    def available?
      !!Rails.application.credentials.openai&.api_key
    rescue => e
      Rails.logger.error("OpenAI availability check error: #{e.message}")
      false
    end
  end
end