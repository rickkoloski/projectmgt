module Api
  module V1
    class TaskDependenciesController < ApplicationController
      include SupabaseUserContext
      
      # Skip authentication temporarily for testing
      # before_action :authenticate_user!
      
      # GET /api/v1/task_dependencies
      def index
        @dependencies = TaskDependency.all
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