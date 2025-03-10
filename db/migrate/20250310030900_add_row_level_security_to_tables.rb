class AddRowLevelSecurityToTables < ActiveRecord::Migration[8.0]
  def up
    # Enable row level security on tables
    execute <<-SQL
      -- Enable RLS on organizations
      ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
      
      -- Enable RLS on projects
      ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
      
      -- Enable RLS on tasks
      ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
      
      -- Enable RLS on task_dependencies
      ALTER TABLE task_dependencies ENABLE ROW LEVEL SECURITY;
      
      -- Enable RLS on shared_links
      ALTER TABLE shared_links ENABLE ROW LEVEL SECURITY;
      
      -- Enable RLS on permissions
      ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
      
      -- Enable RLS on external_notifications
      ALTER TABLE external_notifications ENABLE ROW LEVEL SECURITY;
      
      -- Create app_user role for application access
      DO
      $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_user') THEN
          CREATE ROLE app_user;
        END IF;
      END
      $$;

      -- Create function to get current user id (will be set by application)
      CREATE OR REPLACE FUNCTION current_user_id()
      RETURNS INTEGER AS $$
      DECLARE
        user_id INTEGER;
      BEGIN
        -- This will be set by the application via set_config
        user_id := current_setting('app.current_user_id', TRUE);
        IF user_id IS NULL THEN
          RETURN NULL;
        END IF;
        RETURN user_id::INTEGER;
      EXCEPTION WHEN OTHERS THEN
        RETURN NULL;
      END;
      $$ LANGUAGE plpgsql SECURITY DEFINER;
      
      -- Create function to get user's organization id
      CREATE OR REPLACE FUNCTION user_organization_id(user_id INTEGER)
      RETURNS INTEGER AS $$
      DECLARE
        org_id INTEGER;
      BEGIN
        SELECT organization_id INTO org_id FROM users WHERE id = user_id;
        RETURN org_id;
      END;
      $$ LANGUAGE plpgsql SECURITY DEFINER;
      
      -- Create function to check if user has permission for a resource
      CREATE OR REPLACE FUNCTION has_permission(
        p_user_id INTEGER,
        p_resource_type TEXT,
        p_resource_id INTEGER,
        p_permission_level TEXT
      )
      RETURNS BOOLEAN AS $$
      DECLARE
        user_role TEXT;
        has_perm BOOLEAN;
      BEGIN
        -- Get user role
        SELECT role INTO user_role FROM users WHERE id = p_user_id;
        
        -- Admin users have all permissions
        IF user_role = 'admin' THEN
          RETURN TRUE;
        END IF;
        
        -- Check for explicit permission
        SELECT EXISTS (
          SELECT 1 FROM permissions 
          WHERE user_id = p_user_id 
            AND resource_type = p_resource_type 
            AND resource_id = p_resource_id
            AND (
              (p_permission_level = 'read' AND permission_level IN ('read', 'write', 'admin'))
              OR (p_permission_level = 'write' AND permission_level IN ('write', 'admin'))
              OR (p_permission_level = 'admin' AND permission_level = 'admin')
            )
        ) INTO has_perm;
        
        RETURN has_perm;
      END;
      $$ LANGUAGE plpgsql SECURITY DEFINER;
    SQL
    
    # Create RLS policies
    execute <<-SQL
      -- Organizations policies
      CREATE POLICY organization_read_policy ON organizations 
        FOR SELECT 
        USING (
          owner_id = current_user_id() 
          OR id IN (SELECT organization_id FROM users WHERE id = current_user_id())
        );
        
      CREATE POLICY organization_insert_policy ON organizations 
        FOR INSERT 
        WITH CHECK (current_user_id() IS NOT NULL);
        
      CREATE POLICY organization_update_policy ON organizations 
        FOR UPDATE 
        USING (owner_id = current_user_id());
        
      CREATE POLICY organization_delete_policy ON organizations 
        FOR DELETE 
        USING (owner_id = current_user_id());
      
      -- Projects policies
      CREATE POLICY project_read_policy ON projects 
        FOR SELECT 
        USING (
          organization_id IN (SELECT organization_id FROM users WHERE id = current_user_id())
          OR EXISTS (
            SELECT 1 FROM permissions 
            WHERE user_id = current_user_id() 
              AND resource_type = 'Project' 
              AND resource_id = projects.id
              AND permission_level IN ('read', 'write', 'admin')
          )
        );
        
      CREATE POLICY project_insert_policy ON projects 
        FOR INSERT 
        WITH CHECK (
          organization_id IN (SELECT organization_id FROM users WHERE id = current_user_id())
        );
        
      CREATE POLICY project_update_policy ON projects 
        FOR UPDATE 
        USING (
          organization_id IN (
            SELECT organization_id FROM users 
            WHERE id = current_user_id() AND role IN ('admin', 'member')
          )
          OR has_permission(current_user_id(), 'Project', id, 'write')
        );
        
      CREATE POLICY project_delete_policy ON projects 
        FOR DELETE 
        USING (
          organization_id IN (
            SELECT organization_id FROM users 
            WHERE id = current_user_id() AND role = 'admin'
          )
          OR has_permission(current_user_id(), 'Project', id, 'admin')
        );
      
      -- Tasks policies
      CREATE POLICY task_read_policy ON tasks 
        FOR SELECT 
        USING (
          project_id IN (
            SELECT id FROM projects 
            WHERE organization_id IN (SELECT organization_id FROM users WHERE id = current_user_id())
          )
          OR creator_id = current_user_id()
          OR assignee_id = current_user_id()
          OR EXISTS (
            SELECT 1 FROM permissions 
            WHERE user_id = current_user_id() 
              AND resource_type = 'Task' 
              AND resource_id = tasks.id
              AND permission_level IN ('read', 'write', 'admin')
          )
        );
        
      CREATE POLICY task_insert_policy ON tasks 
        FOR INSERT 
        WITH CHECK (
          project_id IN (
            SELECT id FROM projects 
            WHERE organization_id IN (SELECT organization_id FROM users WHERE id = current_user_id())
          )
          OR has_permission(current_user_id(), 'Project', project_id, 'write')
        );
        
      CREATE POLICY task_update_policy ON tasks 
        FOR UPDATE 
        USING (
          creator_id = current_user_id()
          OR assignee_id = current_user_id()
          OR has_permission(current_user_id(), 'Task', id, 'write')
          OR project_id IN (
            SELECT id FROM projects 
            WHERE organization_id IN (
              SELECT organization_id FROM users 
              WHERE id = current_user_id() AND role IN ('admin', 'member')
            )
          )
        );
        
      CREATE POLICY task_delete_policy ON tasks 
        FOR DELETE 
        USING (
          creator_id = current_user_id()
          OR has_permission(current_user_id(), 'Task', id, 'admin')
          OR project_id IN (
            SELECT id FROM projects 
            WHERE organization_id IN (
              SELECT organization_id FROM users 
              WHERE id = current_user_id() AND role = 'admin'
            )
          )
        );
        
      -- Task dependencies policies (inherit from tasks)
      CREATE POLICY dependency_read_policy ON task_dependencies 
        FOR SELECT 
        USING (
          task_id IN (SELECT id FROM tasks WHERE creator_id = current_user_id() OR assignee_id = current_user_id())
          OR dependent_task_id IN (SELECT id FROM tasks WHERE creator_id = current_user_id() OR assignee_id = current_user_id())
          OR task_id IN (
            SELECT id FROM tasks 
            WHERE project_id IN (
              SELECT id FROM projects 
              WHERE organization_id IN (SELECT organization_id FROM users WHERE id = current_user_id())
            )
          )
        );
        
      CREATE POLICY dependency_insert_policy ON task_dependencies 
        FOR INSERT 
        WITH CHECK (
          task_id IN (SELECT id FROM tasks WHERE creator_id = current_user_id())
          OR task_id IN (
            SELECT id FROM tasks 
            WHERE project_id IN (
              SELECT id FROM projects 
              WHERE organization_id IN (
                SELECT organization_id FROM users 
                WHERE id = current_user_id() AND role IN ('admin', 'member')
              )
            )
          )
        );
        
      CREATE POLICY dependency_update_policy ON task_dependencies 
        FOR UPDATE 
        USING (
          task_id IN (SELECT id FROM tasks WHERE creator_id = current_user_id())
          OR task_id IN (
            SELECT id FROM tasks 
            WHERE project_id IN (
              SELECT id FROM projects 
              WHERE organization_id IN (
                SELECT organization_id FROM users 
                WHERE id = current_user_id() AND role IN ('admin', 'member')
              )
            )
          )
        );
        
      CREATE POLICY dependency_delete_policy ON task_dependencies 
        FOR DELETE 
        USING (
          task_id IN (SELECT id FROM tasks WHERE creator_id = current_user_id())
          OR task_id IN (
            SELECT id FROM tasks 
            WHERE project_id IN (
              SELECT id FROM projects 
              WHERE organization_id IN (
                SELECT organization_id FROM users 
                WHERE id = current_user_id() AND role IN ('admin', 'member')
              )
            )
          )
        );
        
      -- Shared links policies
      CREATE POLICY shared_link_read_policy ON shared_links 
        FOR SELECT 
        USING (
          creator_id = current_user_id()
          OR resource_type = 'Task' AND resource_id IN (
            SELECT id FROM tasks WHERE creator_id = current_user_id() OR assignee_id = current_user_id()
          )
          OR resource_type = 'Project' AND resource_id IN (
            SELECT id FROM projects 
            WHERE organization_id IN (
              SELECT organization_id FROM users WHERE id = current_user_id()
            )
          )
        );
        
      CREATE POLICY shared_link_insert_policy ON shared_links 
        FOR INSERT 
        WITH CHECK (
          creator_id = current_user_id()
        );
        
      CREATE POLICY shared_link_update_policy ON shared_links 
        FOR UPDATE 
        USING (
          creator_id = current_user_id()
        );
        
      CREATE POLICY shared_link_delete_policy ON shared_links 
        FOR DELETE 
        USING (
          creator_id = current_user_id()
        );
        
      -- Permissions policies
      CREATE POLICY permission_read_policy ON permissions 
        FOR SELECT 
        USING (
          user_id = current_user_id()
          OR granted_by = current_user_id()
          OR resource_type = 'Organization' AND resource_id IN (
            SELECT id FROM organizations WHERE owner_id = current_user_id()
          )
          OR resource_type = 'Project' AND resource_id IN (
            SELECT id FROM projects 
            WHERE organization_id IN (
              SELECT id FROM organizations WHERE owner_id = current_user_id()
            )
          )
        );
        
      CREATE POLICY permission_insert_policy ON permissions 
        FOR INSERT 
        WITH CHECK (
          granted_by = current_user_id()
          OR resource_type = 'Organization' AND resource_id IN (
            SELECT id FROM organizations WHERE owner_id = current_user_id()
          )
          OR resource_type = 'Project' AND resource_id IN (
            SELECT id FROM projects 
            WHERE has_permission(current_user_id(), 'Project', resource_id, 'admin')
          )
          OR resource_type = 'Task' AND resource_id IN (
            SELECT id FROM tasks 
            WHERE creator_id = current_user_id()
            OR has_permission(current_user_id(), 'Task', resource_id, 'admin')
          )
        );
        
      CREATE POLICY permission_update_policy ON permissions 
        FOR UPDATE 
        USING (
          granted_by = current_user_id()
          OR resource_type = 'Organization' AND resource_id IN (
            SELECT id FROM organizations WHERE owner_id = current_user_id()
          )
          OR resource_type = 'Project' AND resource_id IN (
            SELECT id FROM projects 
            WHERE has_permission(current_user_id(), 'Project', resource_id, 'admin')
          )
        );
        
      CREATE POLICY permission_delete_policy ON permissions 
        FOR DELETE 
        USING (
          granted_by = current_user_id()
          OR resource_type = 'Organization' AND resource_id IN (
            SELECT id FROM organizations WHERE owner_id = current_user_id()
          )
        );
        
      -- External notifications policies
      CREATE POLICY notification_read_policy ON external_notifications 
        FOR SELECT 
        USING (
          task_id IN (SELECT id FROM tasks WHERE creator_id = current_user_id() OR assignee_id = current_user_id())
          OR task_id IN (
            SELECT id FROM tasks 
            WHERE project_id IN (
              SELECT id FROM projects 
              WHERE organization_id IN (
                SELECT organization_id FROM users WHERE id = current_user_id() AND role = 'admin'
              )
            )
          )
        );
        
      CREATE POLICY notification_insert_policy ON external_notifications 
        FOR INSERT 
        WITH CHECK (
          task_id IN (SELECT id FROM tasks WHERE creator_id = current_user_id())
          OR task_id IN (
            SELECT id FROM tasks 
            WHERE has_permission(current_user_id(), 'Task', task_id, 'write')
          )
        );
        
      CREATE POLICY notification_update_policy ON external_notifications 
        FOR UPDATE 
        USING (
          task_id IN (SELECT id FROM tasks WHERE creator_id = current_user_id())
          OR task_id IN (
            SELECT id FROM tasks 
            WHERE has_permission(current_user_id(), 'Task', task_id, 'write')
          )
        );
        
      CREATE POLICY notification_delete_policy ON external_notifications 
        FOR DELETE 
        USING (
          task_id IN (SELECT id FROM tasks WHERE creator_id = current_user_id())
          OR task_id IN (
            SELECT id FROM tasks 
            WHERE has_permission(current_user_id(), 'Task', task_id, 'admin')
          )
        );
    SQL
  end

  def down
    # Disable row level security on tables
    execute <<-SQL
      -- Delete all policies
      DROP POLICY IF EXISTS organization_read_policy ON organizations;
      DROP POLICY IF EXISTS organization_insert_policy ON organizations;
      DROP POLICY IF EXISTS organization_update_policy ON organizations;
      DROP POLICY IF EXISTS organization_delete_policy ON organizations;
      
      DROP POLICY IF EXISTS project_read_policy ON projects;
      DROP POLICY IF EXISTS project_insert_policy ON projects;
      DROP POLICY IF EXISTS project_update_policy ON projects;
      DROP POLICY IF EXISTS project_delete_policy ON projects;
      
      DROP POLICY IF EXISTS task_read_policy ON tasks;
      DROP POLICY IF EXISTS task_insert_policy ON tasks;
      DROP POLICY IF EXISTS task_update_policy ON tasks;
      DROP POLICY IF EXISTS task_delete_policy ON tasks;
      
      DROP POLICY IF EXISTS dependency_read_policy ON task_dependencies;
      DROP POLICY IF EXISTS dependency_insert_policy ON task_dependencies;
      DROP POLICY IF EXISTS dependency_update_policy ON task_dependencies;
      DROP POLICY IF EXISTS dependency_delete_policy ON task_dependencies;
      
      DROP POLICY IF EXISTS shared_link_read_policy ON shared_links;
      DROP POLICY IF EXISTS shared_link_insert_policy ON shared_links;
      DROP POLICY IF EXISTS shared_link_update_policy ON shared_links;
      DROP POLICY IF EXISTS shared_link_delete_policy ON shared_links;
      
      DROP POLICY IF EXISTS permission_read_policy ON permissions;
      DROP POLICY IF EXISTS permission_insert_policy ON permissions;
      DROP POLICY IF EXISTS permission_update_policy ON permissions;
      DROP POLICY IF EXISTS permission_delete_policy ON permissions;
      
      DROP POLICY IF EXISTS notification_read_policy ON external_notifications;
      DROP POLICY IF EXISTS notification_insert_policy ON external_notifications;
      DROP POLICY IF EXISTS notification_update_policy ON external_notifications;
      DROP POLICY IF EXISTS notification_delete_policy ON external_notifications;
      
      -- Disable RLS
      ALTER TABLE organizations DISABLE ROW LEVEL SECURITY;
      ALTER TABLE projects DISABLE ROW LEVEL SECURITY;
      ALTER TABLE tasks DISABLE ROW LEVEL SECURITY;
      ALTER TABLE task_dependencies DISABLE ROW LEVEL SECURITY;
      ALTER TABLE shared_links DISABLE ROW LEVEL SECURITY;
      ALTER TABLE permissions DISABLE ROW LEVEL SECURITY;
      ALTER TABLE external_notifications DISABLE ROW LEVEL SECURITY;
      
      -- Drop functions
      DROP FUNCTION IF EXISTS current_user_id();
      DROP FUNCTION IF EXISTS user_organization_id(INTEGER);
      DROP FUNCTION IF EXISTS has_permission(INTEGER, TEXT, INTEGER, TEXT);
      
      -- Drop role
      DROP ROLE IF EXISTS app_user;
    SQL
  end
end
