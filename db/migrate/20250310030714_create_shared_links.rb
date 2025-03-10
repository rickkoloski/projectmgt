class CreateSharedLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :shared_links do |t|
      t.string :token
      t.string :resource_type
      t.integer :resource_id
      t.integer :creator_id
      t.datetime :expires_at
      t.jsonb :permissions
      t.integer :max_uses
      t.integer :use_count

      t.timestamps
    end
    add_index :shared_links, :token, unique: true
  end
end
