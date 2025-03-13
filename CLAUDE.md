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

### REST Principles
- **Always follow RESTful architecture** for controller actions and routes
- Use standard CRUD operations and RESTful routes (index, show, new, create, edit, update, destroy)
- Ask before deviating from REST principles - only do so when absolutely necessary
- Maintain clean resource-oriented URL structure (e.g., `/projects/:id` rather than `/delete_project/:id`)

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

### AJAX and CSRF Protection
- For AJAX requests that modify data (POST, PUT, DELETE):
  1. Include the CSRF token in headers: `'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')`
  2. Set content type: `'Content-Type': 'application/json'`
  3. Add the Ajax header: `'X-Requested-With': 'XMLHttpRequest'`
  4. Set credentials: `credentials: 'same-origin'`
- For form submissions:
  1. Use `form_with` with `authenticity_token: true`
  2. For dynamic forms, ensure token is included: `<%= hidden_field_tag :authenticity_token, form_authenticity_token %>`
- Always handle both HTML and JSON responses in controllers using `respond_to` blocks

### Modal Dialogs and CRUD Operations
- **Prefer fetch API over form submissions** for delete/update operations from modal dialogs:

```javascript
// Standard pattern for delete operations
function setupDeleteOperation(buttonSelector, confirmSelector, itemIdAttribute) {
  // Setup variables
  const deleteButtons = document.querySelectorAll(buttonSelector);
  const confirmButton = document.getElementById(confirmSelector);
  let itemToDeleteId;
  
  // Set item ID when delete button is clicked
  deleteButtons.forEach(button => {
    button.addEventListener('click', function(e) {
      e.preventDefault();
      itemToDeleteId = this.getAttribute(itemIdAttribute);
    });
  });
  
  // Handle confirmation and perform delete
  confirmButton.addEventListener('click', function() {
    const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
    
    // Use fetch for the delete operation
    fetch(`/resource_path/${itemToDeleteId}`, {
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': csrfToken,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      },
      credentials: 'same-origin'
    })
    .then(response => {
      if (response.ok) {
        window.location.href = '/success_path';
      } else {
        // Handle errors
        alert('Operation failed. Please try again.');
      }
    })
    .catch(error => {
      console.error('Error:', error);
    });
  });
}
```

- **Controller Implementation** for handling both HTML and JSON:

```ruby
def destroy
  @resource = Resource.find(params[:id])
  
  if @resource.destroy
    respond_to do |format|
      format.html { redirect_to resources_path, notice: 'Resource deleted successfully.' }
      format.json { render json: { success: true }, status: :ok }
    end
  else
    respond_to do |format|
      format.html { redirect_back fallback_location: resources_path, alert: 'Failed to delete.' }
      format.json { render json: { success: false, errors: @resource.errors.full_messages }, status: :unprocessable_entity }
    end
  end
end
```

- **Variables Initialization**: Always define all required variables before using them in JavaScript
- **Error Handling**: Include proper error handling in both JavaScript fetch calls and Ruby controllers

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