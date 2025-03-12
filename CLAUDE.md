# Harmoniq Project Management - Claude Guidelines

## Project Overview
Harmoniq is a project management application built with Ruby on Rails and Vue.js.
- Rails backend with PostgreSQL database
- Vue.js frontend components
- Supabase integration with row-level security
- AI chat functionality (OpenAI/Ollama integrations)

## Common Commands

### Server
- **Start Rails server**: `bin/rails server` or `bin/dev`
- **Restart server**: `bin/fullrestart`
- **View routes**: `bin/rails routes`

### Database
- **Run migrations**: `bin/rails db:migrate`
- **Reset database**: `bin/rails db:reset`
- **Seed database**: `bin/rails db:seed`

### Frontend
- **JS console check**: `console.log('tasks loaded:', window.initialData?.tasks?.length)`
- **Checking Vue mount**: `console.log('Vue app mounted on:', document.getElementById('main-app'))`

## Architecture Guidelines

### Navigation Structure
- **Avoid iframes** for navigation - caused issues with header persistence and URL handling
- Use direct links with proper URL updates for navigation between views
- Vue components should be directly embedded in the page rather than in iframes

### Page Structure
- **App Header**: Contains app title, logout button, and (when on project page) project subtitle
- **Left Nav**: Contains Home (dashboard) icon and application views (Gantt, Board, Resources)
- **Main Content**: Contains the primary view content
- **AI Chat**: Fixed position chat panel

### JavaScript/Vue Patterns
- Vue app mounts to `#main-app` element
- Global data is passed via `window.initialData` from Rails to Vue
- Pass project-specific data via data attributes on the mount element
- Ensure navigation updates the URL properly

## Known Issues & Fixes

### Project Header Persistence
- Problem: Project headers were persisting across pages due to iframe isolation
- Solution: Removed iframe approach in favor of direct DOM rendering
- Implementation: Added project subtitle within app-title div

### Navigation Between Views
- Problem: Navigation wasn't correctly cleaning up the DOM or updating URLs
- Solution: Use standard anchor tags with direct href for navigation
- Implementation: Removed JavaScript event-based navigation

### Data Loading
- Project data should be loaded directly in controller and passed via initialData
- Task data should be scoped to correct project via project_id parameter
- API controllers (/api/v1/tasks) must filter by project_id parameter

## Code Style

### Ruby/Rails
- Use two spaces for indentation
- Follow RESTful controller patterns
- Use the current_user.has_permission? method consistently for access control

### JavaScript/Vue
- Component names use PascalCase
- Data properties and methods use camelCase
- Prefer computed properties over methods for derived data
- Use v-if/v-for directives for conditional rendering