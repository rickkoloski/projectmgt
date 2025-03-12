class DashboardController < ApplicationController
  before_action :authenticate_user!
  
  def index
    # Load projects for the current user
    @organization = current_user.organization
    
    # Get all projects the user has access to
    @projects = if current_user.admin?
      # Admins see all projects
      Project.all.order(updated_at: :desc)
    elsif @organization
      # Organization members see their organization's projects
      @organization.projects.order(updated_at: :desc)
    else
      # Users without organization just see projects they're directly assigned to
      project_ids = []
      
      # Get projects from tasks they created
      project_ids += current_user.created_tasks.pluck(:project_id)
      
      # Get projects from tasks assigned to them
      project_ids += current_user.assigned_tasks.pluck(:project_id)
      
      # Get projects they have direct permissions for
      project_permissions = current_user.permissions.where(resource_type: 'Project').pluck(:resource_id)
      project_ids += project_permissions
      
      Project.where(id: project_ids.uniq).order(updated_at: :desc)
    end
    
    # Template options for new projects
    @project_templates = [
      {
        id: 'scrum',
        name: 'New Scrum Project',
        description: 'Create a project with Scrum artifacts including user stories, sprints, and retrospectives.',
        icon: '🔄'
      },
      {
        id: 'safe',
        name: 'New SAFe Project',
        description: 'Create a project with Scaled Agile Framework elements including ARTs, PI planning, and features.',
        icon: '🚂'
      },
      {
        id: 'blank',
        name: 'New Blank Project',
        description: 'Start with a clean slate and customize your project structure from scratch.',
        icon: '📝'
      }
    ]
  end
  
  def create_from_template
    template_id = params[:template_id]
    project_name = params[:project_name] || "New Project (#{Time.current.strftime('%b %d')})"
    
    # Create new project
    @project = Project.new(
      name: project_name,
      organization_id: current_user.organization_id,
      status: 'active',
      start_date: Date.current,
      end_date: 1.month.from_now.to_date
    )
    
    if @project.save
      # Add template-specific tasks based on the selected template
      case template_id
      when 'scrum'
        create_scrum_template_tasks(@project)
      when 'safe'
        create_safe_template_tasks(@project)
      when 'blank'
        # No tasks for blank template
      end
      
      redirect_to project_path(@project), notice: "Project created successfully!"
    else
      redirect_to dashboard_path, alert: "Failed to create project: #{@project.errors.full_messages.join(', ')}"
    end
  end
  
  private
  
  def create_scrum_template_tasks(project)
    # Create Sprint 1
    sprint1 = project.tasks.create!(
      name: "Sprint 1",
      start_date: Date.current,
      due_date: 2.weeks.from_now.to_date,
      status: "in_progress",
      description: "First sprint"
    )
    
    # Create common Scrum activities
    sprint1.subtasks.create!(
      project: project,
      name: "Sprint Planning",
      start_date: Date.current,
      due_date: Date.current + 1.day,
      status: "not_started"
    )
    
    sprint1.subtasks.create!(
      project: project,
      name: "Daily Standups",
      start_date: Date.current + 1.day,
      due_date: 2.weeks.from_now.to_date - 1.day,
      status: "not_started"
    )
    
    sprint1.subtasks.create!(
      project: project,
      name: "Sprint Review",
      start_date: 2.weeks.from_now.to_date - 1.day,
      due_date: 2.weeks.from_now.to_date,
      status: "not_started"
    )
    
    sprint1.subtasks.create!(
      project: project,
      name: "Sprint Retrospective",
      start_date: 2.weeks.from_now.to_date,
      due_date: 2.weeks.from_now.to_date,
      status: "not_started"
    )
    
    # Create Product Backlog
    backlog = project.tasks.create!(
      name: "Product Backlog",
      start_date: Date.current,
      due_date: 1.month.from_now.to_date,
      status: "not_started",
      description: "Product backlog items"
    )
    
    # Create sample user stories
    backlog.subtasks.create!(
      project: project,
      name: "User Story 1: User Login",
      start_date: Date.current,
      due_date: Date.current + 5.days,
      status: "not_started",
      description: "As a user, I want to be able to login to access my account"
    )
    
    backlog.subtasks.create!(
      project: project,
      name: "User Story 2: User Dashboard",
      start_date: Date.current + 3.days,
      due_date: Date.current + 10.days,
      status: "not_started",
      description: "As a user, I want to see a dashboard with my project information"
    )
  end
  
  def create_safe_template_tasks(project)
    # Create Program Increment (PI)
    pi = project.tasks.create!(
      name: "Program Increment 1",
      start_date: Date.current,
      due_date: 10.weeks.from_now.to_date,
      status: "not_started",
      description: "First program increment"
    )
    
    # Create PI Planning event
    pi.subtasks.create!(
      project: project,
      name: "PI Planning",
      start_date: Date.current,
      due_date: Date.current + 2.days,
      status: "not_started",
      description: "Program increment planning session"
    )
    
    # Create Iterations (similar to sprints)
    iteration1 = pi.subtasks.create!(
      project: project,
      name: "Iteration 1",
      start_date: Date.current + 3.days,
      due_date: Date.current + 17.days,
      status: "not_started"
    )
    
    iteration2 = pi.subtasks.create!(
      project: project,
      name: "Iteration 2",
      start_date: Date.current + 18.days,
      due_date: Date.current + 32.days,
      status: "not_started"
    )
    
    # Create System Demo
    pi.subtasks.create!(
      project: project,
      name: "System Demo",
      start_date: 10.weeks.from_now.to_date - 2.days,
      due_date: 10.weeks.from_now.to_date - 1.day,
      status: "not_started"
    )
    
    # Create Inspect & Adapt
    pi.subtasks.create!(
      project: project,
      name: "Inspect & Adapt",
      start_date: 10.weeks.from_now.to_date - 1.day,
      due_date: 10.weeks.from_now.to_date,
      status: "not_started"
    )
    
    # Create Features
    feature_task = project.tasks.create!(
      name: "Features",
      start_date: Date.current,
      due_date: 10.weeks.from_now.to_date,
      status: "not_started",
      description: "Product features"
    )
    
    # Add sample features
    feature_task.subtasks.create!(
      project: project,
      name: "Feature 1: Authentication System",
      start_date: Date.current + 3.days,
      due_date: Date.current + 24.days,
      status: "not_started"
    )
    
    feature_task.subtasks.create!(
      project: project,
      name: "Feature 2: Reporting Dashboard",
      start_date: Date.current + 25.days,
      due_date: Date.current + 60.days,
      status: "not_started"
    )
  end
end