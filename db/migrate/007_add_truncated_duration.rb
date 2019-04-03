require_relative '../../environment/environment'
class AddTruncatedDuration < ActiveRecord::Migration[5.0]
  def self.up
    change_table :videos do |t|
      t.integer :tr_duration, index: true, null: true, default: 0
    end
  end

  def self.down
  end
end
