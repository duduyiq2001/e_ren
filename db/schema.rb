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

ActiveRecord::Schema[8.1].define(version: 2025_11_16_203625) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "event_categories", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.string "icon"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "event_posts", force: :cascade do |t|
    t.integer "capacity", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "event_category_id", null: false
    t.datetime "event_time", null: false
    t.text "formatted_address"
    t.string "google_maps_url"
    t.string "google_place_id"
    t.decimal "latitude", precision: 10, scale: 6
    t.string "location_name"
    t.decimal "longitude", precision: 10, scale: 6
    t.string "name", null: false
    t.bigint "organizer_id", null: false
    t.integer "registrations_count", default: 0, null: false
    t.boolean "requires_approval", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["event_category_id", "event_time"], name: "index_event_posts_on_event_category_id_and_event_time"
    t.index ["event_category_id"], name: "index_event_posts_on_event_category_id"
    t.index ["event_time"], name: "index_event_posts_on_event_time"
    t.index ["latitude", "longitude"], name: "index_event_posts_on_latitude_and_longitude"
    t.index ["organizer_id"], name: "index_event_posts_on_organizer_id"
    t.index ["requires_approval"], name: "index_event_posts_on_requires_approval"
  end

  create_table "event_registrations", force: :cascade do |t|
    t.boolean "attendance_confirmed", default: false, null: false
    t.datetime "created_at", null: false
    t.bigint "event_post_id", null: false
    t.datetime "registered_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["event_post_id"], name: "index_event_registrations_on_event_post_id"
    t.index ["user_id", "event_post_id"], name: "index_event_registrations_on_user_and_event", unique: true
    t.index ["user_id"], name: "index_event_registrations_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.integer "e_score", default: 0, null: false
    t.string "email", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.string "name", null: false
    t.string "phone_number"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["e_score"], name: "index_users_on_e_score"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "event_posts", "event_categories"
  add_foreign_key "event_posts", "users", column: "organizer_id"
  add_foreign_key "event_registrations", "event_posts"
  add_foreign_key "event_registrations", "users"
end
