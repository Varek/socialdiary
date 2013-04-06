class AddFieldsToUser < ActiveRecord::Migration
  def change
    add_column :users, :notebook_guid, :string
    add_column :users, :current_stacked_notebook_guid, :string
    add_column :users, :last_diary_created_at, :datetime
  end
end
