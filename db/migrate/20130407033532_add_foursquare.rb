class AddFoursquare < ActiveRecord::Migration
  def change
    add_column :users, :foursquare_token, :string
  end
end
