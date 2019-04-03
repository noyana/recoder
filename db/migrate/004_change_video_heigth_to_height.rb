require_relative '../../environment/environment'
class ChangeVideoHeigthToHeight < ActiveRecord::Migration[5.0]
  def self.up
    rename_column :videos, :heigth, :height
  end

end