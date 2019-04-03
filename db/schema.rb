# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 0) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "people", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
    t.text "name"
    t.bigint "count", default: 1
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "people_videos", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
    t.bigint "video_id"
    t.bigint "person_id"
  end

  create_table "videos", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
    t.text "file_name"
    t.bigint "file_size"
    t.text "name"
    t.text "ext", default: ".mp4"
    t.float "duration"
    t.bigint "file_count", default: 1
    t.boolean "is_movie", default: false
    t.datetime "file_date"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.bigint "width", default: 854
    t.bigint "height", default: 480
    t.decimal "frame_rate", precision: 6, scale: 3
    t.float "tr_duration", default: 0.0
  end

end
