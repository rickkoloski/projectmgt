class GanttController < ApplicationController
  # Allow unauthenticated users to see the landing page
  skip_before_action :authenticate_user!, only: [:index]
  
  def index
    # Check if user is logged in
    if current_user
      # Load projects and tasks for the current user
      @organization = current_user.organization
      
      if @organization
        @projects = @organization.projects
        @tasks = Task.joins(:project)
                     .where(projects: { organization_id: @organization.id })
                     .or(Task.where(creator_id: current_user.id))
                     .or(Task.where(assignee_id: current_user.id))
      else
        # User has no organization, just show their own tasks
        @projects = []
        @tasks = current_user.created_tasks.or(current_user.assigned_tasks)
      end
      
      # Format tasks for the Gantt chart
      @gantt_data = {
        projects: @projects.as_json(only: [:id, :name, :start_date, :end_date, :status]),
        tasks: @tasks.as_json(
          only: [:id, :name, :description, :start_date, :due_date, :status, :priority, :percent_complete],
          include: {
            project: { only: [:id, :name] },
            creator: { only: [:id, :name] },
            assignee: { only: [:id, :name] },
            subtasks: { only: [:id, :name, :percent_complete] }
          }
        )
      }
      
      render :dashboard
    else
      # For unauthenticated users, show the landing page
      render :landing
    end
  end
end