class Task < ApplicationRecord
  include RowLevelSecurity
  
  # Add progress attribute accessor that maps to percent_complete
  alias_attribute :progress, :percent_complete
  
  # Ensure progress is included in JSON serialization
  def as_json(options = {})
    super(options).tap do |hash|
      hash['progress'] = percent_complete if percent_complete.present?
      hash['gantt_order'] = gantt_order if gantt_order.present?
      hash['board_order'] = board_order if board_order.present?
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
  before_validation :set_default_order, on: :create
  before_save :reorder_tasks_if_order_changed
  
  # Scopes for ordered tasks
  scope :gantt_ordered, -> { order(:gantt_order) }
  scope :board_ordered, -> { order(:board_order) }
  scope :ordered_by_status, -> { order(:status, :board_order) }
  
  # Class methods for reordering
  class << self
    # Reorder tasks in gantt view
    def reorder_gantt(project_id, task_id, new_position)
      Rails.logger.info "Task.reorder_gantt called with: project_id=#{project_id}, task_id=#{task_id}, new_position=#{new_position}"
      
      return false unless task_id.present? && new_position.present?
      
      # Bypass Row Level Security for this method
      Rails.logger.info "Bypassing Row Level Security for task reordering"
      
      task = without_rls.find_by(id: task_id, project_id: project_id)
      
      if !task
        Rails.logger.error "Task not found: id=#{task_id}, project_id=#{project_id}"
        return false
      end
      
      Rails.logger.info "Found task: #{task.name} (#{task.id}), current gantt_order=#{task.gantt_order}"
      
      # Get all tasks in the same project, bypassing RLS
      tasks = without_rls.where(project_id: project_id).order(:gantt_order)
      Rails.logger.info "Total tasks in project: #{tasks.count}"
      
      # Remove task from its current position
      tasks = tasks.to_a
      current_position = tasks.index(task)
      Rails.logger.info "Current task position in array: #{current_position}"
      
      tasks.delete(task)
      
      # Get current positions of all tasks for debugging
      task_positions_before = tasks.map { |t| { id: t.id, name: t.name, order: t.gantt_order } }
      Rails.logger.info "Task positions BEFORE reordering: #{task_positions_before.inspect}"
      
      # Ensure new_position is within bounds
      original_position = new_position
      new_position = [new_position, tasks.length].min
      new_position = [0, new_position].max
      
      Rails.logger.info "Inserting task at position: #{new_position} (adjusted from #{original_position} to be in bounds)"
      
      # Insert task at new position - NOTE: new_position is 0-based from controller
      tasks.insert(new_position, task)
      
      # Log the tasks order after insertion but before saving
      tasks_after_insertion = tasks.map.with_index { |t, i| { id: t.id, name: t.name, position: i, old_order: t.gantt_order } }
      Rails.logger.info "Task positions AFTER insertion but BEFORE saving: #{tasks_after_insertion.inspect}"
      
      # Update order for all tasks
      transaction do
        tasks.each_with_index do |t, index|
          # Use 1-based indexing for database (gantt_order)
          new_order = index + 1
          Rails.logger.info "Setting task #{t.id} (#{t.name}) gantt_order to #{new_order} (at position #{index})"
          
          # Use direct SQL to bypass RLS
          ActiveRecord::Base.connection.execute(
            "UPDATE tasks SET gantt_order = #{new_order} WHERE id = #{t.id}"
          )
        end
      end
      
      # Get final positions of all tasks after updates
      final_tasks = without_rls.where(project_id: project_id).order(:gantt_order)
      final_task_positions = final_tasks.map { |t| { id: t.id, name: t.name, order: t.gantt_order } }
      Rails.logger.info "FINAL task positions AFTER saving: #{final_task_positions.inspect}"
      
      Rails.logger.info "Task reordering complete, task #{task_id} now at position #{new_position}"
      Rails.logger.info "Reloading task to verify order"
      
      # Reload task to get the new order and confirm it worked
      reloaded_task = without_rls.find_by(id: task_id)
      if reloaded_task
        old_order = task.gantt_order
        new_order = reloaded_task.gantt_order
        Rails.logger.info "Task #{task_id} order changed from #{old_order} to #{new_order}"
        
        # Find the index of the task in the sorted list
        final_index = final_tasks.find_index { |t| t.id == task_id }
        Rails.logger.info "Task #{task_id} has index #{final_index} in the sorted list (0-based)"
        
        return true
      else
        Rails.logger.error "Could not reload task after update"
        return false
      end
    end
    
    # Reorder tasks in board view (within a status column)
    def reorder_board(project_id, task_id, new_position, status)
      Rails.logger.info "Task.reorder_board called with: project_id=#{project_id}, task_id=#{task_id}, new_position=#{new_position}, status=#{status}"
      
      return false unless task_id.present? && new_position.present?
      
      # Bypass Row Level Security for this method
      Rails.logger.info "Bypassing Row Level Security for board reordering"
      
      task = without_rls.find_by(id: task_id, project_id: project_id)
      if !task
        Rails.logger.error "Task not found: id=#{task_id}, project_id=#{project_id}"
        return false
      end
      
      old_status = task.status
      new_status = status || old_status
      
      Rails.logger.info "Task status: old=#{old_status}, new=#{new_status}"
      
      # If status is changing, handle differently
      if old_status != new_status
        Rails.logger.info "Status is changing from #{old_status} to #{new_status}"
        
        # Shift all tasks in the OLD status down
        without_rls.where(project_id: project_id, status: old_status)
          .where('board_order > ?', task.board_order)
          .each do |t|
            new_order = t.board_order - 1
            ActiveRecord::Base.connection.execute(
              "UPDATE tasks SET board_order = #{new_order} WHERE id = #{t.id}"
            )
          end
        
        # Get max order in the new status
        max_order = without_rls.where(project_id: project_id, status: new_status).maximum(:board_order) || 0
        Rails.logger.info "Max order in new status: #{max_order}"
        
        # If the new position is beyond the end, place at the end
        if new_position.to_i > max_order
          new_board_order = max_order + 1
          Rails.logger.info "Placing task at end with order: #{new_board_order}"
        else
          # Shift all tasks in the new status up to make space
          without_rls.where(project_id: project_id, status: new_status)
            .where('board_order >= ?', new_position.to_i)
            .each do |t|
              new_order = t.board_order + 1
              ActiveRecord::Base.connection.execute(
                "UPDATE tasks SET board_order = #{new_order} WHERE id = #{t.id}"
              )
            end
          
          new_board_order = new_position.to_i
          Rails.logger.info "Placing task at position: #{new_board_order}"
        end
        
        # Update task's status and board_order
        ActiveRecord::Base.connection.execute(
          "UPDATE tasks SET status = '#{new_status}', board_order = #{new_board_order} WHERE id = #{task.id}"
        )
      else
        Rails.logger.info "Status is not changing, reordering within same status column"
        
        # Get all tasks in the same project and status
        tasks = without_rls.where(project_id: project_id, status: status).order(:board_order)
        Rails.logger.info "Total tasks in status #{status}: #{tasks.count}"
        
        # Remove task from its current position
        tasks = tasks.to_a
        current_position = tasks.index(task)
        Rails.logger.info "Current task position in array: #{current_position}"
        
        tasks.delete(task)
        
        # Ensure new_position is within bounds
        new_position = [new_position.to_i, tasks.length].min
        new_position = [0, new_position].max
        
        # Insert task at new position
        tasks.insert(new_position, task)
        
        # Update order for all tasks
        transaction do
          tasks.each_with_index do |t, index|
            new_order = index + 1
            Rails.logger.info "Setting task #{t.id} (#{t.name}) board_order to #{new_order}"
            
            # Use direct SQL to bypass RLS
            ActiveRecord::Base.connection.execute(
              "UPDATE tasks SET board_order = #{new_order} WHERE id = #{t.id}"
            )
          end
        end
      end
      
      Rails.logger.info "Board reordering complete for task #{task_id}"
      # Reload task to verify changes
      reloaded_task = without_rls.find_by(id: task_id)
      if reloaded_task
        Rails.logger.info "Task #{task_id} now has status=#{reloaded_task.status}, board_order=#{reloaded_task.board_order}"
        return true
      else
        Rails.logger.error "Could not reload task after update"
        return false
      end
    end
  end
  
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
  
  def set_default_order
    # For Gantt order, get max order + 1 for the project
    self.gantt_order ||= Task.where(project_id: project_id).maximum(:gantt_order).to_i + 1
    
    # For Board order, get max order + 1 for the project and status combination
    self.board_order ||= Task.where(project_id: project_id, status: status).maximum(:board_order).to_i + 1
  end
  
  def reorder_tasks_if_order_changed
    # Handle manual changes to order attributes
    return unless persisted?
    
    if gantt_order_changed?
      # If moving down (higher order value)
      if gantt_order_was && gantt_order > gantt_order_was
        Task.where(project_id: project_id)
            .where('gantt_order > ? AND gantt_order <= ?', gantt_order_was, gantt_order)
            .where.not(id: id)
            .update_all('gantt_order = gantt_order - 1')
      # If moving up (lower order value)
      elsif gantt_order_was && gantt_order < gantt_order_was
        Task.where(project_id: project_id)
            .where('gantt_order >= ? AND gantt_order < ?', gantt_order, gantt_order_was)
            .where.not(id: id)
            .update_all('gantt_order = gantt_order + 1')
      end
    end
    
    if board_order_changed? || status_changed?
      if status_changed?
        # Handle status changes - update old status column
        Task.where(project_id: project_id, status: status_was)
            .where('board_order > ?', board_order_was)
            .update_all('board_order = board_order - 1')
        
        # Make space in new status column
        Task.where(project_id: project_id, status: status)
            .where('board_order >= ?', board_order)
            .where.not(id: id)
            .update_all('board_order = board_order + 1')
      else
        # Handle board order changes within same status
        # If moving down
        if board_order_was && board_order > board_order_was
          Task.where(project_id: project_id, status: status)
              .where('board_order > ? AND board_order <= ?', board_order_was, board_order)
              .where.not(id: id)
              .update_all('board_order = board_order - 1')
        # If moving up
        elsif board_order_was && board_order < board_order_was
          Task.where(project_id: project_id, status: status)
              .where('board_order >= ? AND board_order < ?', board_order, board_order_was)
              .where.not(id: id)
              .update_all('board_order = board_order + 1')
        end
      end
    end
  end
end
