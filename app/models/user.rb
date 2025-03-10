class User < ApplicationRecord
  include RowLevelSecurity
  
  belongs_to :organization, optional: true
  has_many :created_tasks, class_name: 'Task', foreign_key: 'creator_id', dependent: :nullify
  has_many :assigned_tasks, class_name: 'Task', foreign_key: 'assignee_id', dependent: :nullify
  has_many :permissions, dependent: :destroy
  has_many :shared_links, foreign_key: 'creator_id', dependent: :destroy
  
  has_secure_password
  
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  
  ROLES = %w[admin member guest].freeze
  validates :role, inclusion: { in: ROLES }, allow_nil: true
  
  before_validation :set_default_role, if: -> { role.blank? }
  
  # Authenticate with email and password
  def self.authenticate(email, password)
    # Bypass RLS for authentication
    user = without_rls.find_by(email: email)
    user&.authenticate(password) ? user : nil
  end
  
  # Find by email without RLS for authentication flows
  def self.find_by_email_without_rls(email)
    without_rls.find_by(email: email)
  end
  
  def admin?
    role == 'admin'
  end
  
  def member?
    role == 'member'
  end
  
  def guest?
    role == 'guest'
  end
  
  # Method to check if user has permission for a resource
  def has_permission?(resource, permission_level)
    return true if admin?
    
    resource_type = resource.class.name
    resource_id = resource.id
    
    # Check if user has direct permission
    direct_permission = permissions.exists?(
      resource_type: resource_type,
      resource_id: resource_id,
      permission_level: permission_level
    )
    
    return true if direct_permission
    
    # Check organization-level access for projects
    if resource_type == 'Project' && organization_id.present?
      return resource.organization_id == organization_id && member?
    end
    
    # Check project-level access for tasks
    if resource_type == 'Task' && organization_id.present?
      project = resource.project
      return project.organization_id == organization_id && member?
    end
    
    false
  end
  
  # Invite a user to join the organization
  def invite_user(email, name, role = 'member')
    user = User.find_by_email_without_rls(email)
    
    if user
      # User exists, add them to the organization if they don't have one
      if user.organization_id.nil?
        user.update(organization_id: organization_id)
      end
    else
      # Create a new user with a temporary password
      temp_password = SecureRandom.hex(8)
      user = User.create(
        email: email,
        name: name,
        password: temp_password,
        password_confirmation: temp_password,
        organization_id: organization_id,
        role: role
      )
    end
    
    # TODO: Send invitation email with reset password link
    
    user
  end
  
  private
  
  def set_default_role
    self.role = 'member'
  end
end
