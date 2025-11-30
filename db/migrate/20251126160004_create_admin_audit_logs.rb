class CreateAdminAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_audit_logs do |t|
      t.references :admin_user, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false # 'delete', 'restore', 'permanent_delete'
      t.string :target_type, null: false
      t.integer :target_id, null: false
      t.jsonb :metadata, default: {}
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end

    add_index :admin_audit_logs, [:target_type, :target_id]
    add_index :admin_audit_logs, :created_at
    add_index :admin_audit_logs, :action
  end
end

