class AddAttendanceConfirmedToEventRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :event_registrations, :attendance_confirmed, :boolean, default: false, null: false
  end
end
