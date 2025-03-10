class TaskDependency < ApplicationRecord
  include RowLevelSecurity
  
  belongs_to :task
  belongs_to :dependent_task, class_name: 'Task'
  
  validates :task_id, :dependent_task_id, presence: true
  validate :not_self_dependent
  validate :no_circular_dependency
  
  # Types of dependencies
  DEPENDENCY_TYPES = %w[finish_to_start start_to_start finish_to_finish start_to_finish].freeze
  validates :dependency_type, inclusion: { in: DEPENDENCY_TYPES }
  
  before_validation :set_default_dependency_type, if: -> { dependency_type.blank? }
  
  private
  
  # Ensure a task doesn't depend on itself
  def not_self_dependent
    if task_id == dependent_task_id
      errors.add(:dependent_task_id, "can't be the same as task")
    end
  end
  
  # Check for circular dependencies
  def no_circular_dependency
    # Skip this validation if there are other errors
    return if errors.any?
    
    # Check if the dependent task already depends on this task
    if TaskDependency.exists?(task_id: dependent_task_id, dependent_task_id: task_id)
      errors.add(:dependent_task_id, "would create a circular dependency")
    end
    
    # TODO: Add more complex circular dependency detection if needed
  end
  
  def set_default_dependency_type
    self.dependency_type = 'finish_to_start'
  end
end
