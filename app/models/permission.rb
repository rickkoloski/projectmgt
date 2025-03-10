class Permission < ApplicationRecord
  include RowLevelSecurity
  
  belongs_to :user
  
  validates :user_id, :resource_type, :resource_id, presence: true
  validates :permission_level, presence: true
  
  # Ensure uniqueness for user/resource combination
  validates :user_id, uniqueness: { 
    scope: [:resource_type, :resource_id],
    message: "already has a permission for this resource" 
  }
  
  # Permission levels
  PERMISSION_LEVELS = %w[read write admin].freeze
  validates :permission_level, inclusion: { in: PERMISSION_LEVELS }
  
  # Find the resource this permission refers to
  def resource
    resource_type.constantize.find_by(id: resource_id)
  end
  
  # Check if this permission allows a specific action
  def allows?(action)
    case action.to_s
    when 'read'
      %w[read write admin].include?(permission_level)
    when 'write'
      %w[write admin].include?(permission_level)
    when 'admin'
      permission_level == 'admin'
    else
      false
    end
  end
end
