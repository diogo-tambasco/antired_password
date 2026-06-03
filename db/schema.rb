# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_03_190000) do
  create_table "access_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.binary "encrypted_dek", null: false
    t.binary "encrypted_dek_nonce", null: false
    t.datetime "expires_at"
    t.datetime "last_used_at"
    t.string "name", null: false
    t.string "public_id", null: false
    t.binary "token_salt", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["public_id"], name: "index_access_tokens_on_public_id", unique: true
    t.index ["user_id"], name: "index_access_tokens_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "name"], name: "index_projects_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.binary "encrypted_dek", null: false
    t.binary "encrypted_dek_nonce", null: false
    t.binary "master_salt", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "vault_entries", force: :cascade do |t|
    t.binary "ciphertext"
    t.datetime "created_at", null: false
    t.integer "kind", default: 0, null: false
    t.json "metadata", default: {}
    t.string "name"
    t.binary "nonce"
    t.integer "project_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["project_id"], name: "index_vault_entries_on_project_id"
    t.index ["user_id"], name: "index_vault_entries_on_user_id"
  end

  add_foreign_key "access_tokens", "users"
  add_foreign_key "projects", "users"
  add_foreign_key "vault_entries", "projects"
  add_foreign_key "vault_entries", "users"
end
