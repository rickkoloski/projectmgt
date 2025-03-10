class Project < ApplicationRecord
  include RowLevelSecurity
  
  belongs_to :organization
  has_many :tasks, dependent: :destroy
  
  validates :name, presence: true
  validates :organization, presence: true
  
  # Status options
  STATUSES = %w[planning active on_hold completed archived].freeze
  validates :status, inclusion: { in: STATUSES }, allow_nil: true
  
  before_validation :set_default_status, if: -> { status.blank? }
  
  # Get top-level tasks (those without a parent)
  def root_tasks
    tasks.where(parent_id: nil)
  end
  
  # Get all tasks organized in a hierarchy
  def task_hierarchy
    task_hash = {}
    root_task_ids = Set.new(root_tasks.pluck(:id))
    
    # Create a hash of parent_id => [child_tasks]
    tasks.each do |task|
      if task.parent_id.nil?
        # This is a root task
        task_hash[task.id] ||= { task: task, children: [] }
      else
        # This is a child task
        task_hash[task.parent_id] ||= { task: nil, children: [] }
        task_hash[task.parent_id][:children] << task
      end
    end
    
    # Return the root tasks with their nested children
    root_task_ids.map { |id| task_hash[id] }.compact
  end
  
  private
  
  def set_default_status
    self.status = 'planning'
  end
end
