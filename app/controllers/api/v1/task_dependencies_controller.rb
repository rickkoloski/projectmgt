module Api
  module V1
    class TaskDependenciesController < ApplicationController
      include SupabaseUserContext
      
      # Skip authentication temporarily for testing
      # before_action :authenticate_user!
      
      # GET /api/v1/task_dependencies
      def index
        # Get dependencies filtered by project_id if provided
        if params[:project_id].present?
          # Find task IDs belonging to the specified project
          task_ids = Task.where(project_id: params[:project_id]).pluck(:id)
          
          # Find dependencies where either the from or to task is in this project
          @dependencies = TaskDependency.where(task_id: task_ids)
                                       .or(TaskDependency.where(dependent_task_id: task_ids))
        else
          @dependencies = TaskDependency.all
        end
        
        render json: @dependencies
      end
      
      # POST /api/v1/task_dependencies
      def create
        @dependency = TaskDependency.new(dependency_params)
        
        if @dependency.save
          render json: @dependency, status: :created
        else
          render json: { errors: @dependency.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/task_dependencies/:id
      def destroy
        @dependency = TaskDependency.find(params[:id])
        @dependency.destroy
        head :no_content
      end
      
      private
      
      def dependency_params
        params.require(:task_dependency).permit(:task_id, :dependent_task_id, :dependency_type)
      end
    end
  end
end