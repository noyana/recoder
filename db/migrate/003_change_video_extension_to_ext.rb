require_relative '../../environment/environment'
class ChangeVideoExtensionToExt < ActiveRecord::Migration[5.0]
  def self.up
    rename_column :videos, :extension, :ext
  end

  def self.down
    rename_column :videos, :ext, :extension
  end
end