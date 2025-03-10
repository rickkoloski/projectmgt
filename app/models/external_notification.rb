class ExternalNotification < ApplicationRecord
  include RowLevelSecurity
  
  belongs_to :task
  
  validates :recipient_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :subject, :content, presence: true
  
  # Status options
  STATUSES = %w[pending sent delivered read failed].freeze
  validates :status, inclusion: { in: STATUSES }
  
  # Notification types
  NOTIFICATION_TYPES = %w[task_assignment task_update task_reminder task_share task_completion].freeze
  validates :notification_type, inclusion: { in: NOTIFICATION_TYPES }
  
  before_validation :set_default_status, if: -> { status.blank? }
  
  # Mark notification as sent
  def mark_as_sent!
    update(status: 'sent', sent_at: Time.current)
  end
  
  # Mark notification as read
  def mark_as_read!
    update(status: 'read', read_at: Time.current)
  end
  
  # Check if notification has been read
  def read?
    status == 'read' && read_at.present?
  end
  
  # Find notifications by recipient email without RLS
  # This allows accessing notifications for non-authenticated users
  def self.find_by_recipient_email_without_rls(email)
    without_rls.where(recipient_email: email)
  end
  
  private
  
  def set_default_status
    self.status = 'pending'
  end
end
