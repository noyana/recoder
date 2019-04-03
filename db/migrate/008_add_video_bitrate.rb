require_relative '../../environment/environment'
class AddVideoBitrate < ActiveRecord::Migration
  def self.up
    change_table :videos do |t|
      t.integer :bit_rate, index: true, null: true, default: 896
    end
  end

  def self.down
  end
end
