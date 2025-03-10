class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.string :name
      t.text :description
      t.references :project, null: false, foreign_key: true
      t.integer :assignee_id
      t.integer :creator_id
      t.date :start_date
      t.date :due_date
      t.string :status
      t.string :priority
      t.integer :percent_complete
      t.integer :parent_id
      t.jsonb :metadata

      t.timestamps
    end
  end
end
