class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name, null: false
      t.string :phone_number
      t.integer :e_score, default: 0, null: false

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :e_score
  end
end
