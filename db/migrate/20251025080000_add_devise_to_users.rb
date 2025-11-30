class AddDeviseToUsers < ActiveRecord::Migration[8.1]
  def change
    # Remove old password_digest column
    remove_column :users, :password_digest, :string if column_exists?(:users, :password_digest)

    # Add Devise required columns
    change_table :users do |t|
      ## Database authenticatable
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable (optional but useful)
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip
    end

    # Add indexes (only if they don't exist)
    add_index :users, :email, unique: true unless index_exists?(:users, :email)
    add_index :users, :reset_password_token, unique: true
  end
end

