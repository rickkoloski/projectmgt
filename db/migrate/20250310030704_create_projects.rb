class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :name
      t.text :description
      t.references :organization, null: false, foreign_key: true
      t.date :start_date
      t.date :end_date
      t.string :status
      t.jsonb :settings

      t.timestamps
    end
  end
end
