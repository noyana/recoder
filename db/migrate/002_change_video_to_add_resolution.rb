require_relative '../../environment/environment'
class ChangeVideoToAddResolution < ActiveRecord::Migration[5.0]
  def self.up
    change_table :videos do |t|
      t.integer :width, index: true, null: true, default: 854
      t.integer :heigth, index: true, null: true, default: 480
    end
  end

  def self.down
    change_table :videos do |t|
      remove_column :width
      remove_column :heigth
    end
  end
end