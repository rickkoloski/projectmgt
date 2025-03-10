class SharedLink < ApplicationRecord
  include RowLevelSecurity
  
  belongs_to :creator, class_name: 'User', optional: true
  
  validates :token, presence: true, uniqueness: true
  validates :resource_type, :resource_id, presence: true
  
  before_validation :generate_token, if: -> { token.blank? }
  
  # Find the resource this link refers to
  def resource
    resource_type.constantize.find_by(id: resource_id)
  end
  
  # Check if this shared link is valid (not expired, not over max uses)
  def valid_for_use?
    return false if expired?
    return false if max_uses.present? && use_count >= max_uses
    true
  end
  
  # Check if the link is expired
  def expired?
    expires_at.present? && expires_at < Time.current
  end
  
  # Record a use of this link
  def record_use!
    increment!(:use_count)
  end
  
  # Check if a specific action is allowed
  def allows_action?(action)
    return false unless valid_for_use?
    permissions.present? && permissions[action.to_s] == true
  end
  
  # Find a shared link by token without RLS
  # This allows non-authenticated users to access shared resources
  def self.find_by_token_without_rls(token)
    without_rls.find_by(token: token)
  end
  
  private
  
  def generate_token
    self.token = SecureRandom.urlsafe_base64(12)
    
    # Ensure token uniqueness
    while SharedLink.exists?(token: self.token)
      self.token = SecureRandom.urlsafe_base64(12)
    end
  end
end
