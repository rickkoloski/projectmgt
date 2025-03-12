require 'net/http'
require 'uri'
require 'json'

module Api
  module V1
    class AiChatController < ApplicationController
      include SupabaseUserContext
      
      # Temporarily skip authentication for testing
      # before_action :authenticate_user!

      # POST /api/v1/ai_chat/message
      def message
        prompt = params[:prompt]
        
        if prompt.blank?
          render json: { error: "Prompt cannot be empty" }, status: :bad_request
          return
        end
        
        # Check if this is a request to generate tasks - be more liberal in detection
        task_keywords = ['task', 'project', 'plan', 'schedule', 'gantt', 'timeline']
        create_keywords = ['create', 'generate', 'make', 'build', 'develop', 'setup']
        
        prompt_lower = prompt.downcase
        is_task_request = false
        
        # Check if at least one word from each category is in the prompt
        create_match = create_keywords.any? { |word| prompt_lower.include?(word) }
        task_match = task_keywords.any? { |word| prompt_lower.include?(word) }
        
        if create_match && task_match
          # This is definitely a task generation request
          Rails.logger.info("Detected task generation request: #{prompt}")
          generate_tasks(prompt)
          return
        end
        
        # Regular chat message flow
        # First try to get a real response from Ollama - try multiple model names
        # Try model names in order of preference until one works
        model_names = ['llama3.1', 'llama3.2', 'llama3', 'llama3:8b', 'llama2', 'llama2:7b']
        model = ENV.fetch('OLLAMA_DEFAULT_MODEL', model_names.first)
        
        begin
          # Very simple implementation - just the core functionality
          response_text = call_ollama(prompt, model)
          
          render json: {
            response: response_text,
            provider: "ollama",
            model: model
          }
        rescue => e
          Rails.logger.error("Ollama error: #{e.message}. Falling back to mock response.")
          
          # If Ollama fails, fall back to the mock response
          response_text = get_mock_response(prompt)
          
          render json: {
            response: response_text,
            provider: "mock",
            model: "fallback"
          }
        end
      end
      
      # POST /api/v1/ai_chat/generate_tasks
      def generate_tasks(prompt = nil)
        # If prompt not provided as parameter, get it from request
        prompt ||= params[:prompt]
        
        if prompt.blank?
          render json: { error: "Prompt cannot be empty" }, status: :bad_request
          return
        end
        
        # Use the LLM to generate a project plan
        begin
          model_names = ['llama3.1', 'llama3.2', 'llama3', 'llama3:8b', 'llama2', 'llama2:7b']
          model = ENV.fetch('OLLAMA_DEFAULT_MODEL', model_names.first)
          
          # Specific prompt for task generation - make it very explicit
          system_message = "You are a project management assistant that helps create structured project plans. Your task is to parse the user's request and generate a complete project plan with tasks, subtasks, dates, and dependencies. Create descriptive task names that are specific and action-oriented. Provide detailed task descriptions that explain what work needs to be done. YOU MUST RESPOND WITH VALID JSON ONLY. DO NOT PROVIDE EXPLANATIONS OR TEXT BEFORE OR AFTER THE JSON."
          
          # Task generation instructions
          instructions = <<~INSTRUCTIONS
            Based on the user's request, generate a project plan in JSON format following these requirements:
            
            JSON STRUCTURE:
            {
              "tasks": [
                {
                  "name": "Task name (brief, specific, action-oriented title, 5-10 words)",
                  "description": "More detailed task description explaining what needs to be done (25-50 words)",
                  "start_date": "YYYY-MM-DD",
                  "end_date": "YYYY-MM-DD",  // This will map to due_date in our system
                  "status": "todo",
                  "progress": 0,             // This will map to percent_complete in our system
                  "project_id": 1,
                  "parent_id": null
                }
              ],
              "dependencies": [
                {
                  "from": 1,
                  "to": 2,
                  "type": "finish_to_start"
                }
              ]
            }
            
            CRITICAL REQUIREMENTS:
            - RESPOND WITH VALID JSON ONLY - NO TEXT BEFORE OR AFTER THE JSON
            - DO NOT USE MARKDOWN CODE BLOCKS OR FORMATTING
            - THE JSON MUST BE VALID AND WELL-FORMED
            - Start dates should begin on or after #{Date.today.to_s}
            - End dates must be after start dates
            - Include at least 5 tasks and 3 dependencies
            - Include at least 2 parent tasks with subtasks
            - Parent tasks should have null start_date and end_date 
            - Task IDs in dependencies refer to the index+1 in the tasks array (1-indexed)
            - For task names, use concise, specific, action-oriented phrases (e.g., "Design User Interface Wireframes", not "Task 1")
            - For task descriptions, include detailed information about deliverables, methodology, or requirements
            - Valid dependency types: finish_to_start, start_to_start, finish_to_finish, start_to_finish
            - Valid status values: todo, inProgress, review, done, backlog (these will be mapped to our system's values)
            
            YOUR ENTIRE RESPONSE MUST BE VALID JSON. NO TEXT BEFORE OR AFTER THE JSON.
            YOUR RESPONSE MUST START WITH '{' AND END WITH '}'.
          INSTRUCTIONS
          
          full_prompt = "#{system_message}\n\n#{instructions}\n\nUser request: #{prompt}\n\nJSON response:"
          
          # Call LLM with increased timeout
          response = call_ollama_with_timeout(full_prompt, model, 120)
          
          # Log the raw response for debugging
          Rails.logger.info("Raw LLM response: #{response.gsub(/\n/, '\\n')[0..500]}...")
          
          # Extract JSON from the response
          json_text = extract_json_from_text(response)
          Rails.logger.info("Extracted JSON: #{json_text.gsub(/\n/, '\\n')[0..500]}...")
          
          begin
            task_data = JSON.parse(json_text)
            
            # Verify we have the required structure
            unless task_data.is_a?(Hash) && task_data["tasks"].is_a?(Array) && task_data["dependencies"].is_a?(Array)
              raise "LLM response has invalid structure. Need tasks and dependencies arrays."
            end
            
            # Make sure all required fields are present and meaningful
            task_data["tasks"].each_with_index do |task, index|
              # Default name if missing
              if task["name"].nil? || task["name"].strip.empty?
                task["name"] = "Task #{index + 1}"
              end
              
              # Default description if missing
              if task["description"].nil? || task["description"].strip.empty?
                if task["name"].match?(/^Task \d+$/i)
                  # If name is generic, create a slightly more meaningful description
                  task["description"] = "Complete activities for #{task["name"].downcase}"
                else
                  # Otherwise, use the name as basis for description
                  task["description"] = "Complete the '#{task["name"]}' activities as specified in the project plan"
                end
              end
              
              # If we have a generic "Task N" name but a real description, use first part of description as name
              if task["name"].match?(/^Task \d+$/i) && task["description"].length > 10
                # Extract first sentence or phrase (up to 50 chars) for name
                potential_name = task["description"].split(/[.;:]/).first
                if potential_name.length > 50
                  potential_name = potential_name[0..49].gsub(/\s\w+$/, '...')
                end
                task["name"] = potential_name
              end
              
              # Set other defaults
              task["status"] ||= "todo"
              task["progress"] ||= 0
              task["project_id"] ||= 1
            end
            
          rescue JSON::ParserError => e
            Rails.logger.error("JSON parsing error: #{e.message}")
            raise "Could not parse JSON from LLM response: #{e.message}"
          end
          
          # Send the task data to the tasks controller to create them
          result = replace_tasks(task_data["tasks"], task_data["dependencies"], prompt)
          
          if result[:success]
            # Return success message with more details
            task_names = task_data['tasks'].map { |t| t['name'] }.first(3).join(", ")
            tasks_count = task_data['tasks'].size
            deps_count = task_data['dependencies'].size
            
            render json: {
              response: "✅ Success! I've created a project plan with #{tasks_count} tasks and #{deps_count} dependencies. The plan includes tasks such as: #{task_names}, and more. You can see the full plan in the Gantt chart now - it has replaced the previous tasks.",
              provider: "ollama",
              model: model,
              action: "refresh_tasks",  # Signal to frontend to refresh tasks
              project_id: result[:project_id],  # Send the project ID from the result
              tasks_created: tasks_count,
              dependencies_created: deps_count
            }
          else
            # Error creating tasks
            render json: {
              response: "I generated a project plan but had trouble creating the tasks in the system. Please try again with a simpler request.",
              provider: "ollama",
              model: model,
              error: "Failed to create tasks"
            }
          end
        rescue => e
          Rails.logger.error("Task generation error: #{e.message}")
          
          # Return error message
          render json: {
            response: "I had difficulty creating a project plan from your request. Please try providing more specific details about the project timeline and tasks. Error: #{e.message}",
            provider: "ollama",
            model: model,
            error: e.message
          }
        end
      end
      
      # Call Ollama API directly with minimal code
      def call_ollama(prompt, model)
        host = ENV.fetch('OLLAMA_URL', 'http://localhost:11434')
        
        # Try to find a model that works, starting with the preferred one
        model_names = ['llama3.1', 'llama3.2', 'llama3', 'llama3:8b', 'llama2', 'llama2:7b']
        model_names.unshift(model) unless model_names.include?(model)  # Add user's preferred model first
        
        last_error = nil
        
        # Try each model in succession
        model_names.each do |model_name|
          begin
            # Format per Ollama API docs: https://github.com/ollama/ollama/blob/main/docs/api.md
            system_message = "You are a helpful assistant for a project management application. Provide concise, practical advice about project management features. Keep responses under 150 words.\n\nThis is a project management app with features including Gantt charts, task boards, and resource management. Users can create tasks, set deadlines, track dependencies, and assign resources to tasks."
            
            # Full prompt with system message
            full_prompt = "#{system_message}\n\nUser: #{prompt}\nAssistant:"
            
            uri = URI.parse("#{host}/api/generate")
            http = Net::HTTP.new(uri.host, uri.port)
            http.open_timeout = 10  # Increased for connection issues
            http.read_timeout = 60  # Longer timeout for model generation
            
            # Build request according to Ollama API format
            request = Net::HTTP::Post.new(uri.request_uri)
            request.content_type = 'application/json'
            request.body = {
              model: model_name,
              prompt: full_prompt,
              stream: false  # Don't stream the response
            }.to_json
            
            # For debugging - log the request
            Rails.logger.info("Trying Ollama model: #{model_name}")
            
            # Send the request
            response = http.request(request)
            
            # For debugging - log the response
            Rails.logger.info("Ollama response status: #{response.code}")
            
            # Parse the response
            if response.code.to_i == 200
              result = JSON.parse(response.body)
              return result['response']
            elsif response.code.to_i == 404 && response.body.include?("model '#{model_name}' not found")
              # Model not found, try the next one
              last_error = "Model '#{model_name}' not found"
              next
            else
              # Other error
              last_error = "Ollama API error with model #{model_name}: #{response.code} - #{response.body}"
              next
            end
          rescue => e
            last_error = e.message
            next
          end
        end
        
        # If we get here, all models failed
        raise "All Ollama models failed. Last error: #{last_error}"
      end
      
      # Generate a mock response for testing (fallback if Ollama is unavailable)
      def get_mock_response(prompt)
        prompt_lower = prompt.downcase
        
        if prompt_lower.include?('what') && (prompt_lower.include?('app') || prompt_lower.include?('application'))
          return "This is a project management application that helps you organize tasks, track deadlines, and collaborate with team members. It includes features like Gantt charts for timeline visualization, task boards for kanban-style workflows, and resource management tools."
        elsif prompt_lower.include?('hello') || prompt_lower.include?('hi') || prompt_lower.match?(/^hey/)
          return "Hello! I'm your project management assistant. How can I help you today?"
        elsif prompt_lower.include?('task') && (prompt_lower.include?('create') || prompt_lower.include?('add') || prompt_lower.include?('new'))
          return "To create a new task, click the 'Add Task' button in the toolbar above the workspace. You can then enter the task details, set deadlines, and assign resources."
        elsif prompt_lower.include?('gantt')
          return "The Gantt chart view shows your project timeline with tasks represented as horizontal bars. You can see dependencies between tasks, track progress, and identify potential bottlenecks in your project schedule."
        elsif prompt_lower.include?('model') || prompt_lower.include?('llm') || prompt_lower.include?('ai')
          return "I'm using a fallback response system since the LLM connection isn't currently available. In normal operation, I would use Ollama with the llama3 model."
        else
          return "I understand your question about '#{prompt}'. This is a fallback response since the LLM connection isn't working. Please make sure Ollama is running with the command: ollama serve"
        end
      end

      # GET /api/v1/ai_chat/providers
      def providers
        # List of model names we try
        model_names = ['llama3.1', 'llama3.2', 'llama3', 'llama3:8b', 'llama2', 'llama2:7b']
        default_model = ENV.fetch('OLLAMA_DEFAULT_MODEL', model_names.first)
        
        # Try to get available models directly
        begin
          host = ENV.fetch('OLLAMA_URL', 'http://localhost:11434')
          uri = URI.parse("#{host}/api/tags")
          http = Net::HTTP.new(uri.host, uri.port)
          http.read_timeout = 5
          http.open_timeout = 5
          
          response = http.get(uri.request_uri)
          
          if response.code.to_i == 200
            result = JSON.parse(response.body)
            actual_models = result['models']&.map { |m| m['name'] } || []
            
            # Return real models if available
            if actual_models.any?
              render json: { 
                providers: {
                  ollama: {
                    available: true,
                    models: actual_models,
                    default_model: default_model
                  }
                }
              }
              return
            end
          end
        rescue => e
          Rails.logger.error("Error getting Ollama models: #{e.message}")
        end
        
        # Fall back to our predefined list
        render json: { 
          providers: {
            ollama: {
              available: true,
              models: model_names,
              default_model: default_model
            }
          }
        }
      end
      
      # POST /api/v1/ai_chat/generate_tasks_endpoint
      def generate_tasks_endpoint
        generate_tasks
      end
      
      private
      
      # Helper method to call Ollama with a longer timeout
      def call_ollama_with_timeout(prompt, model, timeout = 60)
        host = ENV.fetch('OLLAMA_URL', 'http://localhost:11434')
        
        # Try to find a model that works, starting with the preferred one
        model_names = ['llama3.1', 'llama3.2', 'llama3', 'llama3:8b', 'llama2', 'llama2:7b']
        model_names.unshift(model) unless model_names.include?(model)  # Add user's preferred model first
        
        last_error = nil
        
        # Try each model in succession
        model_names.each do |model_name|
          begin
            uri = URI.parse("#{host}/api/generate")
            http = Net::HTTP.new(uri.host, uri.port)
            http.open_timeout = 15
            http.read_timeout = timeout
            
            # Build request according to Ollama API format
            request = Net::HTTP::Post.new(uri.request_uri)
            request.content_type = 'application/json'
            request.body = {
              model: model_name,
              prompt: prompt,
              stream: false
            }.to_json
            
            # For debugging - log the request
            Rails.logger.info("Trying Ollama model for task generation: #{model_name}")
            
            # Send the request
            response = http.request(request)
            
            # For debugging - log the response
            Rails.logger.info("Ollama task generation response status: #{response.code}")
            
            # Parse the response
            if response.code.to_i == 200
              result = JSON.parse(response.body)
              return result['response']
            elsif response.code.to_i == 404 && response.body.include?("model '#{model_name}' not found")
              # Model not found, try the next one
              last_error = "Model '#{model_name}' not found"
              next
            else
              # Other error
              last_error = "Ollama API error with model #{model_name}: #{response.code} - #{response.body}"
              next
            end
          rescue => e
            last_error = e.message
            next
          end
        end
        
        # If we get here, all models failed
        raise "All Ollama models failed for task generation. Last error: #{last_error}"
      end
      
      # Helper method to extract JSON from text
      def extract_json_from_text(text)
        # First, try to extract JSON enclosed in code blocks
        if text =~ /```(?:json)?\s*(\{.*?\})\s*```/m
          return $1
        end
        
        # Next, try to find the outermost matching braces for complete JSON
        json_match = text.match(/\{.*\}/m)
        if json_match
          potential_json = json_match[0]
          # Validate by counting braces
          open_count = potential_json.count('{')
          close_count = potential_json.count('}')
          
          if open_count == close_count
            return potential_json
          end
        end
        
        # If that didn't work, remove any markdown and try again
        cleaned = text.gsub(/```(?:json)?\s*|\s*```/, '')
        
        # Find the outermost JSON object
        start_idx = cleaned.index('{')
        end_idx = cleaned.rindex('}')
        
        if start_idx && end_idx && start_idx < end_idx
          potential_json = cleaned[start_idx..end_idx]
          
          # Validate that we have matching braces
          open_count = potential_json.count('{')
          close_count = potential_json.count('}')
          
          if open_count == close_count
            return potential_json
          end
        end
        
        # Last resort: try to fix unbalanced JSON
        if start_idx
          # Count opening and closing braces and try to balance them
          content = cleaned[start_idx..-1]
          open_count = content.count('{')
          close_count = content.count('}')
          
          if open_count > close_count
            # Add missing closing braces
            return content + ('}' * (open_count - close_count))
          elsif content.rindex('}')
            # End at the last closing brace
            return content[0..content.rindex('}')]
          end
        end
        
        # If all else fails
        raise "Couldn't extract JSON from the LLM response"
      end
      
      # Helper method to replace tasks through the API
      def replace_tasks(tasks, dependencies, project_prompt = nil)
        # For simplicity, we'll create the tasks directly instead of using the API
        begin
          Rails.logger.info("Starting task replacement with #{tasks.size} tasks and #{dependencies.size} dependencies")
          
          # Variables to return
          result = { success: false, project_id: nil }
          
          # Start a transaction
          ActiveRecord::Base.transaction do
            # Delete existing records in the correct order to handle foreign key constraints
            Rails.logger.info("Deleting external notifications")
            ActiveRecord::Base.connection.execute("DELETE FROM external_notifications")
            
            Rails.logger.info("Deleting permissions")
            ActiveRecord::Base.connection.execute("DELETE FROM permissions WHERE resource_type = 'Task'")
            
            Rails.logger.info("Deleting shared links")
            ActiveRecord::Base.connection.execute("DELETE FROM shared_links WHERE resource_type = 'Task'")
            
            Rails.logger.info("Deleting task dependencies")
            ActiveRecord::Base.connection.execute("DELETE FROM task_dependencies")
            
            Rails.logger.info("Deleting existing tasks")
            ActiveRecord::Base.connection.execute("DELETE FROM tasks")
            
            # Find or create a project for the tasks
            project_description = project_prompt || "AI Generated Project" 
            project_title = project_description.length > 50 ? "#{project_description[0..47]}..." : project_description
            project_name = "AI Generated Project: #{project_title}"
            default_org = Organization.first || Organization.create!(name: "Default Organization", slug: "default")
            
            project = Project.find_or_create_by(name: project_name) do |p|
              p.organization_id = default_org.id
              p.description = "Project created from AI chat: #{project_description}"
              p.start_date = Date.today
              p.end_date = Date.today + 30.days
              p.status = "active"
            end
            
            # Update result with project ID
            result[:project_id] = project.id
            
            Rails.logger.info("Using project: #{project.name} (ID: #{project.id})")
            
            # Create new tasks
            created_tasks = []
            task_id_map = {}  # Map original task IDs to new database IDs
            parent_id_map = {} # Store original parent_id for each task
            
            tasks.each_with_index do |task_data, index|
              # Parse and validate dates
              start_date = parse_date(task_data["start_date"])
              end_date = parse_date(task_data["end_date"])
              
              # Map LLM status to valid Task model status values
              # Valid statuses: not_started, in_progress, on_hold, completed, cancelled
              llm_status = task_data["status"]
              
              # Map from LLM statuses to our application's status values
              status_map = {
                "todo" => "not_started",
                "inProgress" => "in_progress",
                "review" => "on_hold",
                "done" => "completed",
                "backlog" => "not_started",
                # Add default mapping for each allowed status
                "not_started" => "not_started",
                "in_progress" => "in_progress",
                "on_hold" => "on_hold",
                "completed" => "completed",
                "cancelled" => "cancelled"
              }
              
              # Use the mapped status or default to "not_started"
              status = status_map[llm_status] || "not_started"
              
              # Ensure progress is a number
              progress = task_data["progress"].to_i
              progress = 0 if progress < 0 || progress > 100
              
              # Create the task using the correct field names from our schema
              # Get priority if available or use default
              priority = task_data["priority"]
              unless ["low", "medium", "high", "urgent"].include?(priority)
                priority = "medium" # Default priority
              end
              
              # Create task with all the correct field names
              task_name = task_data["name"].to_s.strip
              task_description = task_data["description"].to_s.strip
              
              # If name is still generic despite our preprocessing, use description intelligently
              if task_name.match?(/^task\s+\d+$/i) && task_description.length > 10
                # Use first sentence or up to 80 chars of description for name
                first_sentence = task_description.split(/[.;:!?]/).first.strip
                if first_sentence.length > 80
                  # Truncate if too long and add ellipsis
                  task_name = first_sentence[0..76].gsub(/\s\w+$/, '') + '...'
                else
                  task_name = first_sentence
                end
              end
              
              # If name is too short and generic but not "Task N" format, make it more descriptive
              if task_name.length < 5 && task_description.length > 10
                first_part = task_description.split(/[.;:!?]/).first.strip
                task_name = first_part.length > 80 ? first_part[0..76] + '...' : first_part
              end
              
              # Store the original parent_id for later mapping
              original_parent_id = task_data["parent_id"]
              
              task = Task.new(
                name: task_name,
                description: task_description,
                status: status,
                priority: priority,
                percent_complete: progress, # Use percent_complete instead of progress
                project_id: project.id, # Always use our newly created project
                parent_id: nil, # We'll update parent relationships after all tasks are created
                creator_id: current_user&.id || 1,
                assignee_id: (task_data["assignee_id"] || current_user&.id || 1).to_i
              )
              
              # Only set dates if they're valid
              task.start_date = start_date if start_date
              task.due_date = end_date if end_date # Use due_date instead of end_date
              
              # Save with validation
              task.save!
              
              # Store in our mapping (1-indexed from the LLM)
              task_index = index + 1  # LLM uses 1-indexed IDs
              task_id_map[task_index] = task.id
              created_tasks << task
              
              # Store the original parent ID for this task
              if original_parent_id
                parent_id_map[task.id] = original_parent_id
              end
            end
            
            # FIRST: Update all parent_id relationships now that we have the ID mapping
            Rails.logger.info("Updating parent_id relationships")
            parent_id_map.each do |task_id, original_parent_id|
              # Get the actual database ID for this parent
              if original_parent_id && task_id_map[original_parent_id.to_i]
                real_parent_id = task_id_map[original_parent_id.to_i]
                
                # Update the task with the correct parent_id
                Rails.logger.info("Setting task #{task_id} parent to #{real_parent_id}")
                Task.where(id: task_id).update_all(parent_id: real_parent_id)
              end
            end
            
            # THEN: Create dependencies using the mapping
            if dependencies.is_a?(Array)
              dependencies.each do |dep|
                from_id = task_id_map[dep["from"].to_i]
                to_id = task_id_map[dep["to"].to_i]
                
                # Make sure both tasks exist
                if from_id && to_id
                  # Map to the correct column names in the task_dependencies table
                  TaskDependency.create!(
                    task_id: from_id,                  # from_task_id → task_id
                    dependent_task_id: to_id,          # to_task_id → dependent_task_id
                    dependency_type: dep["type"] || "finish_to_start"
                  )
                end
              end
            end
            
            # Mark as successful
            result[:success] = true
          end
          
          return result
        rescue => e
          Rails.logger.error("Failed to replace tasks: #{e.message}")
          return { success: false, project_id: nil, error: e.message }
        end
      end
      
      # Helper to parse date strings
      def parse_date(date_string)
        return nil if date_string.nil? || date_string == 'null' || date_string.blank?
        
        begin
          # Try parsing as ISO format
          Date.parse(date_string)
        rescue => e
          # If that fails, return today's date
          Rails.logger.warn("Failed to parse date: #{date_string}, error: #{e.message}")
          Date.today
        end
      end
      
      # Collect context relevant to the user
      def collect_context(user)
        context = {}
        
        # Add current user's info if user is authenticated
        if user
          context[:user] = {
            email: user.email,
            name: user.name
          }
          
          # Get user's organizations if the method exists
          if user.respond_to?(:organizations)
            orgs = user.organizations
            if orgs.any?
              context[:organizations] = orgs.map { |org| "#{org.name} (#{org.id})" }.join(", ")
              
              # Get user's projects in those organizations
              projects = Project.where(organization_id: orgs.pluck(:id))
              if projects.any?
                context[:projects] = projects.map { |p| "#{p.name} (#{p.id}): #{p.description}" }.join("\n")
                
                # Get user's recent tasks
                # Limit to recent tasks to avoid context overload
                project_ids = projects.pluck(:id)
                tasks = Task.where(project_id: project_ids).order(updated_at: :desc).limit(10)
                if tasks.any?
                  context[:recent_tasks] = tasks.map do |t|
                    "Task: #{t.name} (#{t.id})\nStatus: #{t.status}\nDue: #{t.due_date}\nDescription: #{t.description}"
                  end.join("\n\n")
                end
              end
            end
          end
        end
        
        context
      end
    end
  end
end