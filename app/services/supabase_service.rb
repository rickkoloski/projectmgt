# frozen_string_literal: true

class SupabaseService
  attr_reader :api_url, :api_key

  def initialize
    @api_url = ENV.fetch('SUPABASE_URL')
    @api_key = ENV.fetch('SUPABASE_API_KEY')
  end

  # Authenticate a user with Supabase
  def sign_in(email, password)
    response = conn.post('/auth/v1/token?grant_type=password') do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = { email: email, password: password }.to_json
    end

    handle_response(response)
  end

  # Sign up a new user
  def sign_up(email, password, user_metadata = {})
    response = conn.post('/auth/v1/signup') do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = { 
        email: email, 
        password: password,
        data: user_metadata
      }.to_json
    end

    handle_response(response)
  end

  # Fetch user data using their JWT
  def get_user(access_token)
    response = conn.get('/auth/v1/user') do |req|
      req.headers['Authorization'] = "Bearer #{access_token}"
    end

    handle_response(response)
  end

  # Make a database query using Supabase's REST API
  def query_db(table, query_params = {})
    path = "/rest/v1/#{table}"
    
    response = conn.get(path) do |req|
      req.params = query_params if query_params.any?
    end

    handle_response(response)
  end

  # Insert a record into a table
  def insert(table, data)
    path = "/rest/v1/#{table}"
    
    response = conn.post(path) do |req|
      req.headers['Content-Type'] = 'application/json'
      req.headers['Prefer'] = 'return=representation'
      req.body = data.to_json
    end

    handle_response(response)
  end

  # Update records in a table
  def update(table, data, query_params = {})
    path = "/rest/v1/#{table}"
    
    response = conn.patch(path) do |req|
      req.headers['Content-Type'] = 'application/json'
      req.headers['Prefer'] = 'return=representation'
      req.params = query_params if query_params.any?
      req.body = data.to_json
    end

    handle_response(response)
  end

  # Delete records from a table
  def delete(table, query_params = {})
    path = "/rest/v1/#{table}"
    
    response = conn.delete(path) do |req|
      req.headers['Prefer'] = 'return=representation'
      req.params = query_params if query_params.any?
    end

    handle_response(response)
  end

  private

  def conn
    @conn ||= Faraday.new(url: api_url) do |f|
      f.request :json
      f.response :json
      f.headers['apikey'] = api_key
      f.headers['Authorization'] = "Bearer #{api_key}"
    end
  end

  def handle_response(response)
    if response.success?
      response.body
    else
      { error: response.body, status: response.status }
    end
  end
end