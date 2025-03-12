module Api
  module V1
    class TasksController < ApplicationController
      include SupabaseUserContext
      
      # Skip authentication and CSRF protection temporarily for testing
      # before_action :authenticate_user!
      skip_before_action :verify_authenticity_token, only: [:replace_all]
      
      # GET /api/v1/tasks
      def index
        # Get all tasks and include necessary associations
        @tasks = Task.includes(:project, :creator, :assignee, :parent).all
        render json: @tasks
      end
      
      # POST /api/v1/tasks
      def create
        @task = Task.new(task_params)
        
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
            params[:tasks].each do |task_data|
              task = Task.create!(
                name: task_data[:name],
                description: task_data[:description],
                start_date: task_data[:start_date],
                end_date: task_data[:end_date],
                status: task_data[:status] || 'todo',
                progress: task_data[:progress] || 0,
                project_id: task_data[:project_id],
                parent_id: task_data[:parent_id],
                creator_id: current_user&.id || 1,
                assignee_id: task_data[:assignee_id]
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
      
      # Other standard CRUD actions (show, update, destroy) go here...
      
      private
      
      def task_params
        params.require(:task).permit(
          :name, :description, :start_date, :end_date, 
          :status, :progress, :project_id, :parent_id, :assignee_id
        )
      end
    end
  end
end