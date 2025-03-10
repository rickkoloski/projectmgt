# This file is auto-generated from the current state of the database.
# Instead of editing this file, please use the migrations to incrementally modify your database,
# and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_03_10_030900) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "external_notifications", force: :cascade do |t|
    t.string "recipient_email"
    t.string "recipient_name"
    t.string "subject"
    t.text "content"
    t.bigint "task_id", null: false
    t.string "status"
    t.string "notification_type"
    t.datetime "sent_at"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id"], name: "index_external_notifications_on_task_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.integer "owner_id"
    t.jsonb "settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_organizations_on_owner_id"
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "permissions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "resource_type"
    t.integer "resource_id"
    t.string "permission_level"
    t.integer "granted_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_permissions_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.bigint "organization_id", null: false
    t.date "start_date"
    t.date "end_date"
    t.string "status"
    t.jsonb "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_projects_on_organization_id"
  end

  create_table "shared_links", force: :cascade do |t|
    t.string "token", null: false
    t.string "resource_type"
    t.integer "resource_id"
    t.integer "creator_id"
    t.datetime "expires_at"
    t.jsonb "permissions"
    t.integer "max_uses"
    t.integer "use_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_shared_links_on_token", unique: true
  end

  create_table "task_dependencies", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "dependent_task_id", null: false
    t.string "dependency_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dependent_task_id"], name: "index_task_dependencies_on_dependent_task_id"
    t.index ["task_id", "dependent_task_id"], name: "index_task_dependencies_on_task_id_and_dependent_task_id", unique: true
    t.index ["task_id"], name: "index_task_dependencies_on_task_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.bigint "project_id", null: false
    t.integer "assignee_id"
    t.integer "creator_id"
    t.date "start_date"
    t.date "due_date"
    t.string "status"
    t.string "priority"
    t.integer "percent_complete"
    t.integer "parent_id"
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_tasks_on_project_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "name"
    t.string "password_digest"
    t.bigint "organization_id"
    t.string "role"
    t.string "auth_provider"
    t.string "auth_uid"
    t.datetime "last_login_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
  end

  add_foreign_key "external_notifications", "tasks"
  add_foreign_key "permissions", "users"
  add_foreign_key "projects", "organizations"
  add_foreign_key "task_dependencies", "tasks"
  add_foreign_key "task_dependencies", "tasks", column: "dependent_task_id"
  add_foreign_key "tasks", "projects"
  add_foreign_key "users", "organizations"
end