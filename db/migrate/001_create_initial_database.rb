require_relative '../../environment/environment'
class CreateInitialDatabase < ActiveRecord::Migration[5.0]
  def self.up
    create_table 'people' do |t|
      t.string 'name', limit: 250, null: false
      t.integer 'count', default: 1
      t.index ['id'], name: 'ndx_people_id_u', unique: true
      t.index ['name'], name: 'ndx_people__name'
      t.timestamps
    end

    create_table 'videos' do |t|
      t.string 'file_name', limit: 250, null: false
      t.integer 'file_size'
      t.string 'name', limit: 250
      t.string 'extension', limit: 6, default: '.mp4'
      t.float 'duration'
      t.integer 'file_count', default: 1
      t.boolean 'is_movie', default: 0
      t.datetime 'file_date'
      t.index ['file_name'], name: 'ndx_videos_file_name_u', unique: true
      t.index ['file_size'], name: 'ndx_videos_file_size'
      t.index ['id'], name: 'ndx_videos_id_u', unique: true
      t.index ['is_movie'], name: 'ndx_videos_is_movie'
      t.timestamps
    end

  end

  def self.down
    drop_table :videos
    drop_table :people
  end
end