class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email
      t.string :name
      t.string :password_digest
      t.references :organization, foreign_key: true
      t.string :role
      t.string :auth_provider
      t.string :auth_uid
      t.datetime :last_login_at

      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end
