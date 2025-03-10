# frozen_string_literal: true

# Initialize Supabase configuration
Rails.application.config.to_prepare do
  # Load ENV variables from .env file in development
  if Rails.env.development? && File.exist?(".env")
    File.readlines(".env").each do |line|
      next if line.strip.empty? || line.strip.start_with?("#")
      key, value = line.strip.split("=", 2)
      ENV[key] = value if key && value
    end
  end
  
  # Validate required Supabase environment variables
  %w[SUPABASE_URL SUPABASE_API_KEY].each do |env_var|
    unless ENV[env_var].present?
      warn "WARNING: #{env_var} environment variable is not set. Supabase integration will not work properly."
    end
  end
end