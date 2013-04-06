class CreateUsers < ActiveRecord::Migration
  def up
    create_table :users do |t|
      t.string :name
      t.string :email
      t.integer :evernote_id
      t.string :evernote_token
      t.integer :twitter_id
      t.string :twitter_token
      t.string :twitter_secret
      t.integer :facebook_id
      t.string :facbook_token
    end
  end

  def down
    drop_table :users
  end
end
