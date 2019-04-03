require_relative '../../environment/environment'
class AddVideoFrameRate < ActiveRecord::Migration[5.0]
  def self.up
    create_join_table :videos, :people do |t|
      t.integer :id
    end
  end

  def self.down
    drop_join_table :videos, :people
  end
end