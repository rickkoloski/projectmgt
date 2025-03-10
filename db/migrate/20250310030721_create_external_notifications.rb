class CreateExternalNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :external_notifications do |t|
      t.string :recipient_email
      t.string :recipient_name
      t.string :subject
      t.text :content
      t.references :task, null: false, foreign_key: true
      t.string :status
      t.string :notification_type
      t.datetime :sent_at
      t.datetime :read_at

      t.timestamps
    end
  end
end
