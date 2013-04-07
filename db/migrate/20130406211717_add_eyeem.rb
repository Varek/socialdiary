class AddEyeem < ActiveRecord::Migration
  def change
    add_column :users, :eyeem_token, :string
  end
end
