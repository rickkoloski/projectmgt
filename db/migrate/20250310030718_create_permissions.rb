class CreatePermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :permissions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :resource_type
      t.integer :resource_id
      t.string :permission_level
      t.integer :granted_by

      t.timestamps
    end
  end
end
