# frozen_string_literal: true

module RowLevelSecurity
  extend ActiveSupport::Concern
  
  included do
    # Default scopes for models with RLS
    # This ensures RLS is applied at the application level
    default_scope { with_current_user_context }
  end
  
  class_methods do
    # Add the user context to all queries
    def with_current_user_context
      all.tap do
        # Apply the current user context for RLS at the database level
        current_user_id = CurrentUser.id
        if current_user_id
          connection.execute("SELECT set_config('app.current_user_id', '#{current_user_id}', false)")
        else
          connection.execute("SELECT set_config('app.current_user_id', '', false)")
        end
      end
    end
    
    # Bypass RLS for administrative functions
    def without_rls
      unscoped.tap do
        # Clear the user context temporarily
        connection.execute("SELECT set_config('app.current_user_id', '', false)")
      end
    end
  end
end

# Thread-local storage for current user ID
class CurrentUser
  def self.id
    Thread.current[:user_id]
  end
  
  def self.id=(id)
    Thread.current[:user_id] = id
  end
end