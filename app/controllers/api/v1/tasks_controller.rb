module Api
  module V1
    class TasksController < ApplicationController
      include SupabaseUserContext
      
      # Skip authentication and CSRF protection temporarily for testing
      # before_action :authenticate_user!
      skip_before_action :verify_authenticity_token, only: [:replace_all, :reorder_gantt, :reorder_board]
      
      # GET /api/v1/tasks
      def index
        # Get tasks filtered by project_id if provided
        if params[:project_id].present?
          @tasks = Task.includes(:project, :creator, :assignee, :parent)
                      .where(project_id: params[:project_id])
                      
          # Apply ordering based on view parameter
          case params[:view]
          when 'gantt'
            @tasks = @tasks.order(:gantt_order)
          when 'board'
            @tasks = @tasks.order(:status, :board_order)
          else
            # Default to gantt ordering
            @tasks = @tasks.order(:gantt_order)
          end
        else
          # Get all tasks and include necessary associations
          @tasks = Task.includes(:project, :creator, :assignee, :parent).all
        end
        
        render json: @tasks
      end
      
      # POST /api/v1/tasks
      def create
        @task = Task.new(prepare_task_params)
        
        if @task.save
          render json: @task, status: :created
        else
          render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/tasks/replace_all
      # Replaces all tasks with new ones (for AI-generated tasks)
      def replace_all
        # Validate the tasks array
        if !params[:tasks].is_a?(Array)
          render json: { error: "Tasks must be an array" }, status: :bad_request
          return
        end
        
        begin
          # Start a transaction
          Task.transaction do
            # Delete existing tasks
            Task.delete_all
            
            # Create new tasks
            @tasks = []
            params[:tasks].each_with_index do |task_data, index|
              task = Task.create!(
                name: task_data[:name],
                description: task_data[:description],
                start_date: task_data[:start_date],
                due_date: task_data[:end_date],
                status: task_data[:status] || 'todo',
                percent_complete: task_data[:progress] || 0,
                project_id: task_data[:project_id],
                parent_id: task_data[:parent_id],
                creator_id: current_user&.id || 1,
                assignee_id: task_data[:assignee_id],
                gantt_order: index + 1,
                board_order: task_data[:board_order] # Will be set automatically if nil
              )
              @tasks << task
            end
            
            # Handle task dependencies after all tasks are created
            if params[:dependencies].is_a?(Array)
              params[:dependencies].each do |dep|
                TaskDependency.create!(
                  from_task_id: dep[:from],
                  to_task_id: dep[:to],
                  dependency_type: dep[:type] || 'finish_to_start'
                )
              end
            end
          end
          
          render json: { tasks: @tasks, message: "Successfully replaced all tasks" }, status: :ok
        rescue => e
          render json: { error: "Failed to replace tasks: #{e.message}" }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/tasks/reorder_gantt
      def reorder_gantt
        project_id = params[:project_id]
        task_id = params[:task_id]
        new_position = params[:position]
        
        Rails.logger.info "Reordering task: project_id=#{project_id}, task_id=#{task_id}, new_position=#{new_position}"
        
        unless project_id.present? && task_id.present? && new_position.present?
          Rails.logger.error "Missing required parameters"
          render json: { error: "Missing required parameters" }, status: :bad_request
          return
        end
        
        # Parse parameters to integers
        project_id = project_id.to_i
        task_id = task_id.to_i
        new_position = new_position.to_i
        
        # The frontend sends a 0-based index, but our database uses 1-based indices
        # Add 1 to properly align with the database's expectation
        adjusted_position = new_position + 1
        
        Rails.logger.info "Reordering task (parsed as integers): project_id=#{project_id}, task_id=#{task_id}, new_position=#{new_position}, adjusted_position=#{adjusted_position}"
        
        Rails.logger.info "About to call Task.reorder_gantt with position: #{adjusted_position}"
        
        # Capture current gantt order for logging
        original_tasks = Task.where(project_id: project_id).order(:gantt_order)
        Rails.logger.info "Original task order: #{original_tasks.map { |t| { id: t.id, name: t.name, order: t.gantt_order } }.inspect}"
        
        reorder_result = Task.reorder_gantt(project_id, task_id, adjusted_position)
        Rails.logger.info "Task.reorder_gantt returned: #{reorder_result}"
        
        if reorder_result
          # Return the updated task list in order
          @tasks = Task.where(project_id: project_id).order(:gantt_order)
          
          # Log the new order for debugging
          Rails.logger.info "Updated task order: #{@tasks.map { |t| { id: t.id, name: t.name, order: t.gantt_order } }.inspect}"
          
          render json: @tasks
        else
          Rails.logger.error "Failed to reorder tasks"
          render json: { error: "Failed to reorder tasks" }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/tasks/reorder_board
      def reorder_board
        project_id = params[:project_id]
        task_id = params[:task_id]
        new_position = params[:position]
        status = params[:status]
        
        Rails.logger.info "Reordering board task: project_id=#{project_id}, task_id=#{task_id}, new_position=#{new_position}, status=#{status}"
        
        unless project_id.present? && task_id.present? && new_position.present?
          Rails.logger.error "Missing required parameters"
          render json: { error: "Missing required parameters" }, status: :bad_request
          return
        end
        
        # Parse parameters to integers
        project_id = project_id.to_i
        task_id = task_id.to_i
        new_position = new_position.to_i
        
        # The frontend sends a 0-based index, but our database uses 1-based indices
        # Add 1 to properly align with the database's expectation
        adjusted_position = new_position + 1
        
        Rails.logger.info "Reordering board task (parsed as integers): project_id=#{project_id}, task_id=#{task_id}, new_position=#{new_position}, adjusted_position=#{adjusted_position}, status=#{status}"
        
        if Task.reorder_board(project_id, task_id, adjusted_position, status)
          # Return the updated task list for the specified status
          @tasks = Task.where(project_id: project_id)
                       .order(:status, :board_order)
          
          render json: @tasks
        else
          Rails.logger.error "Failed to reorder board tasks"
          render json: { error: "Failed to reorder tasks" }, status: :unprocessable_entity
        end
      end
      
      # GET /api/v1/tasks/:id
      def show
        @task = Task.find(params[:id])
        render json: @task
      end
      
      # PATCH/PUT /api/v1/tasks/:id
      def update
        @task = Task.find(params[:id])
        
        if @task.update(prepare_task_params)
          render json: @task
        else
          render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/tasks/:id
      def destroy
        @task = Task.find(params[:id])
        
        if @task.destroy
          render json: { success: true }
        else
          render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      private
      
      def task_params
        params.require(:task).permit(
          :name, :description, :start_date, :due_date, 
          :status, :percent_complete, :project_id, :parent_id, :assignee_id,
          :progress, :gantt_order, :board_order
        )
      end
      
      # Map front-end parameters to database fields
      def prepare_task_params
        task_attributes = task_params
        
        # Map progress to percent_complete if it exists
        if task_attributes[:progress].present?
          task_attributes[:percent_complete] = task_attributes.delete(:progress)
        end
        
        # Ensure endDate maps to due_date
        if params[:task][:endDate].present?
          task_attributes[:due_date] = params[:task][:endDate]
        end
        
        task_attributes
      end
    end
  end
end