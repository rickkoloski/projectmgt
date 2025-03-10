# frozen_string_literal: true

# Thread-local storage for current user ID
class CurrentUser
  def self.id
    Thread.current[:user_id]
  end
  
  def self.id=(id)
    Thread.current[:user_id] = id
  end
end

# Set up database connection hooks for RLS
ActiveSupport.on_load(:active_record) do
  # Set user context for RLS on connection checkout
  ActiveRecord::ConnectionAdapters::AbstractAdapter.set_callback :checkout, :after do |conn|
    if conn.is_a?(ActiveRecord::ConnectionAdapters::AbstractAdapter)
      current_user_id = CurrentUser.id
      if current_user_id
        conn.execute("SELECT set_config('app.current_user_id', '#{current_user_id}', false)")
      else
        conn.execute("SELECT set_config('app.current_user_id', '', false)")
      end
    end
  end
end