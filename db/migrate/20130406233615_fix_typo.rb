class FixTypo < ActiveRecord::Migration
  def change
    rename_column :users, :facbook_token, :facebook_token
  end

end
