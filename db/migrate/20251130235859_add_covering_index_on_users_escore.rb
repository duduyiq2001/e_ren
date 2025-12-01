class AddCoveringIndexOnUsersEscore < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Remove existing e_score index
    remove_index :users, :e_score, if_exists: true

    # Add covering index for leaderboard query: SELECT id, name, email, e_score ORDER BY e_score DESC
    add_index :users, [:e_score, :id, :name, :email],
              order: { e_score: :desc },
              name: "index_users_on_e_score_covering",
              algorithm: :concurrently
  end
end
