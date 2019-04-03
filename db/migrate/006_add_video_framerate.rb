require_relative '../../environment/environment'
class AddVideoFramerate < ActiveRecord::Migration[5.0]
  def self.up
    change_table :videos do |t|
      t.integer :frame_rate, index: true, null: true, default: 854
    end
  end

  def self.down
  end
end
