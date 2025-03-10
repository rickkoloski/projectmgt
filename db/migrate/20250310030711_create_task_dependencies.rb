class CreateTaskDependencies < ActiveRecord::Migration[8.0]
  def change
    create_table :task_dependencies do |t|
      t.references :task, null: false, foreign_key: true
      t.references :dependent_task, null: false
      t.string :dependency_type, null: false

      t.timestamps
    end
    
    # Add a foreign key to tasks for dependent_task
    add_foreign_key :task_dependencies, :tasks, column: :dependent_task_id
    
    # Add a unique constraint to prevent duplicate dependencies
    add_index :task_dependencies, [:task_id, :dependent_task_id], unique: true
  end
end
