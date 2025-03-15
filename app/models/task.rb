class Task < ApplicationRecord
  include RowLevelSecurity
  
  # Add progress attribute accessor that maps to percent_complete
  alias_attribute :progress, :percent_complete
  
  # Ensure progress is included in JSON serialization
  def as_json(options = {})
    super(options).tap do |hash|
      hash['progress'] = percent_complete if percent_complete.present?
    end
  end
  
  belongs_to :project
  belongs_to :creator, class_name: 'User', optional: true
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :parent, class_name: 'Task', optional: true
  
  has_many :subtasks, class_name: 'Task', foreign_key: 'parent_id', dependent: :nullify
  
  # Helper method for creation of child tasks
  def create_subtask(attributes = {})
    subtasks.create!({ project_id: self.project_id }.merge(attributes))
  end
  has_many :dependencies, class_name: 'TaskDependency', dependent: :destroy
  has_many :dependent_tasks, through: :dependencies
  has_many :external_notifications, dependent: :destroy
  
  validates :name, presence: true
  validates :project, presence: true
  
  # Status options
  STATUSES = %w[backlog todo inProgress review done].freeze
  validates :status, inclusion: { in: STATUSES }, allow_nil: true
  
  # Priority options
  PRIORITIES = %w[low medium high urgent].freeze
  validates :priority, inclusion: { in: PRIORITIES }, allow_nil: true
  
  before_validation :set_default_status, if: -> { status.blank? }
  before_validation :set_default_priority, if: -> { priority.blank? }
  
  # Check if this task depends on another task
  def depends_on?(other_task)
    TaskDependency.exists?(task_id: self.id, dependent_task_id: other_task.id)
  end
  
  # Add a dependency to another task
  def add_dependency(other_task, dependency_type = 'finish_to_start')
    unless depends_on?(other_task)
      TaskDependency.create(
        task_id: self.id,
        dependent_task_id: other_task.id,
        dependency_type: dependency_type
      )
    end
  end
  
  # Get all prerequisites (tasks that must be completed before this one)
  def prerequisites
    Task.joins(:dependencies)
        .where(task_dependencies: { dependent_task_id: self.id })
  end
  
  # Share task with an external user
  def share_with_email(email, name = nil, expires_in = 7.days)
    shared_link = SharedLink.create(
      resource_type: self.class.name,
      resource_id: self.id,
      creator_id: self.creator_id,
      expires_at: Time.current + expires_in,
      permissions: { view: true, edit: false },
      max_uses: 10,
      use_count: 0
    )
    
    ExternalNotification.create(
      recipient_email: email,
      recipient_name: name,
      subject: "Task shared with you: #{self.name}",
      content: "You have been invited to view a task. Click the link to access it.",
      task_id: self.id,
      status: 'pending',
      notification_type: 'task_share'
    )
    
    shared_link
  end
  
  private
  
  def set_default_status
    self.status = 'todo'
  end
  
  def set_default_priority
    self.priority = 'medium'
  end
end
