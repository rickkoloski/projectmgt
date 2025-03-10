# This file seeds the database with initial data required to run the application

# Clear existing data
puts "Clearing existing data..."
SharedLink.destroy_all
Permission.destroy_all
ExternalNotification.destroy_all
TaskDependency.destroy_all
Task.destroy_all
Project.destroy_all
User.destroy_all
Organization.destroy_all

# Create admin organization
puts "Creating admin organization..."
admin_org = Organization.create!(
  name: "Admin Organization",
  slug: "admin",
  settings: { theme: "light", logo_url: nil }
)

# Create admin user
puts "Creating admin user..."
admin = User.create!(
  name: "Admin User",
  email: "admin@example.com",
  password: "password123",
  password_confirmation: "password123",
  organization: admin_org,
  role: "admin"
)

# Update organization owner
admin_org.update!(owner_id: admin.id)

# Create demo organization
puts "Creating demo organization..."
demo_org = Organization.create!(
  name: "Demo Organization",
  slug: "demo",
  settings: { theme: "light", logo_url: nil }
)

# Create demo users
puts "Creating demo users..."
demo_admin = User.create!(
  name: "Demo Admin",
  email: "demo_admin@example.com",
  password: "password123",
  password_confirmation: "password123",
  organization: demo_org,
  role: "admin"
)

demo_member = User.create!(
  name: "Demo Member",
  email: "demo_member@example.com",
  password: "password123",
  password_confirmation: "password123",
  organization: demo_org,
  role: "member"
)

demo_guest = User.create!(
  name: "Demo Guest",
  email: "demo_guest@example.com",
  password: "password123",
  password_confirmation: "password123",
  organization: demo_org,
  role: "guest"
)

# Update organization owner
demo_org.update!(owner_id: demo_admin.id)

# Create demo projects
puts "Creating demo projects..."
project1 = Project.create!(
  name: "Website Redesign",
  description: "Complete overhaul of the company website with new branding",
  organization: demo_org,
  start_date: Date.today,
  end_date: Date.today + 30.days,
  status: "active"
)

project2 = Project.create!(
  name: "Mobile App Development",
  description: "New mobile application for customer engagement",
  organization: demo_org,
  start_date: Date.today + 15.days,
  end_date: Date.today + 90.days,
  status: "planning"
)

# Create demo tasks
puts "Creating demo tasks..."
# Tasks for Website Redesign
task1 = Task.create!(
  name: "Design mockups",
  description: "Create design mockups for all pages",
  project: project1,
  creator: demo_admin,
  assignee: demo_member,
  start_date: Date.today,
  due_date: Date.today + 7.days,
  status: "in_progress",
  priority: "high",
  percent_complete: 30
)

task2 = Task.create!(
  name: "Frontend development",
  description: "Implement the HTML/CSS/JS for the new design",
  project: project1,
  creator: demo_admin,
  assignee: demo_member,
  start_date: Date.today + 7.days,
  due_date: Date.today + 21.days,
  status: "not_started",
  priority: "medium",
  percent_complete: 0
)

task3 = Task.create!(
  name: "Backend integration",
  description: "Connect the frontend to the backend API",
  project: project1,
  creator: demo_admin,
  start_date: Date.today + 21.days,
  due_date: Date.today + 28.days,
  status: "not_started",
  priority: "medium",
  percent_complete: 0
)

# Subtasks
subtask1 = Task.create!(
  name: "Homepage design",
  description: "Design the homepage layout",
  project: project1,
  creator: demo_member,
  assignee: demo_member,
  parent: task1,
  start_date: Date.today,
  due_date: Date.today + 3.days,
  status: "completed",
  priority: "high",
  percent_complete: 100
)

subtask2 = Task.create!(
  name: "Product pages design",
  description: "Design the product page layouts",
  project: project1,
  creator: demo_member,
  assignee: demo_member,
  parent: task1,
  start_date: Date.today + 3.days,
  due_date: Date.today + 7.days,
  status: "in_progress",
  priority: "high",
  percent_complete: 50
)

# Tasks for Mobile App
task4 = Task.create!(
  name: "Requirements gathering",
  description: "Collect and document all app requirements",
  project: project2,
  creator: demo_admin,
  assignee: demo_admin,
  start_date: Date.today + 15.days,
  due_date: Date.today + 25.days,
  status: "not_started",
  priority: "high",
  percent_complete: 0
)

task5 = Task.create!(
  name: "App design",
  description: "Create wireframes and visual designs for the app",
  project: project2,
  creator: demo_admin,
  assignee: demo_member,
  start_date: Date.today + 25.days,
  due_date: Date.today + 40.days,
  status: "not_started",
  priority: "medium",
  percent_complete: 0
)

task6 = Task.create!(
  name: "Development",
  description: "Code the mobile application",
  project: project2,
  creator: demo_admin,
  start_date: Date.today + 40.days,
  due_date: Date.today + 80.days,
  status: "not_started",
  priority: "medium",
  percent_complete: 0
)

# Create task dependencies
puts "Creating task dependencies..."
TaskDependency.create!(
  task: task2,
  dependent_task: task1,
  dependency_type: "finish_to_start"
)

TaskDependency.create!(
  task: task3,
  dependent_task: task2,
  dependency_type: "finish_to_start"
)

TaskDependency.create!(
  task: task5,
  dependent_task: task4,
  dependency_type: "finish_to_start"
)

TaskDependency.create!(
  task: task6,
  dependent_task: task5,
  dependency_type: "finish_to_start"
)

# Create permissions
puts "Creating permissions..."
Permission.create!(
  user: demo_guest,
  resource_type: "Project",
  resource_id: project1.id,
  permission_level: "read",
  granted_by: demo_admin.id
)

# Create a shared link
puts "Creating shared links..."
SharedLink.create!(
  token: SecureRandom.urlsafe_base64(12),
  resource_type: "Task",
  resource_id: task1.id,
  creator_id: demo_admin.id,
  expires_at: Date.today + 30.days,
  permissions: { view: true, edit: false },
  max_uses: 10,
  use_count: 0
)

# Create external notification
puts "Creating external notifications..."
ExternalNotification.create!(
  recipient_email: "external@example.com",
  recipient_name: "External User",
  subject: "Task shared with you: #{task1.name}",
  content: "You have been invited to view a task. Click the link to access it.",
  task: task1,
  status: "pending",
  notification_type: "task_share"
)

puts "Seed data created successfully!"
