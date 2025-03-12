# LLM Configuration
Rails.application.configure do
  # Create a custom configuration namespace for LLM settings
  config.llm = ActiveSupport::OrderedOptions.new
  
  # Default preferred provider (:ollama or :openai)
  config.llm.preferred_provider = ENV.fetch('LLM_PREFERRED_PROVIDER', 'ollama')
  
  # Ollama settings
  config.llm.ollama_url = ENV.fetch('OLLAMA_URL', 'http://localhost:11434')
  config.llm.ollama_default_model = ENV.fetch('OLLAMA_DEFAULT_MODEL', 'llama3')
  
  # OpenAI settings
  config.llm.openai_default_model = ENV.fetch('OPENAI_DEFAULT_MODEL', 'gpt-3.5-turbo')
  
  # Configure the Ollama client if using Ollama
  if config.llm.preferred_provider.to_sym == :ollama
    require 'ollama-ai'
    # The ollama-ai gem doesn't use a configure block
    # We'll set the host in the provider directly
  end
end