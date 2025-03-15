class AddOrderingToTasks < ActiveRecord::Migration[8.0]
  def up
    # Add new order columns
    add_column :tasks, :gantt_order, :integer
    add_column :tasks, :board_order, :integer
    
    # Add indexes for efficient sorting
    add_index :tasks, [:project_id, :gantt_order]
    add_index :tasks, [:project_id, :status, :board_order]
    
    # Initialize existing data with sequential order values
    # Group tasks by project for gantt_order
    execute <<-SQL
      UPDATE tasks
      SET gantt_order = subquery.row_number
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY project_id ORDER BY id) as row_number
        FROM tasks
      ) AS subquery
      WHERE tasks.id = subquery.id
    SQL
    
    # Group tasks by project and status for board_order
    execute <<-SQL
      UPDATE tasks
      SET board_order = subquery.row_number
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY project_id, status ORDER BY id) as row_number
        FROM tasks
      ) AS subquery
      WHERE tasks.id = subquery.id
    SQL
  end
  
  def down
    remove_index :tasks, [:project_id, :gantt_order], if_exists: true
    remove_index :tasks, [:project_id, :status, :board_order], if_exists: true
    remove_column :tasks, :gantt_order
    remove_column :tasks, :board_order
  end
end
