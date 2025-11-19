require 'rails_helper'

RSpec.describe "Email Delivery Integration", type: :feature do
  before do
    # 检查环境变量
    unless ENV['GMAIL_USERNAME'] && ENV['GMAIL_PASSWORD']
      skip "GMAIL_USERNAME and GMAIL_PASSWORD environment variables are not set"
    end
  end

  it 'sends real email to jxinran@wustl.edu' do
    puts "🧪 Starting real email integration test..."

    # 创建测试数据
    user = User.find_or_create_by!(email: "jxinran@wustl.edu") do |u|
      u.name = "Jxinran Test"
      u.e_score = 0
    end

    organizer = User.find_or_create_by!(email: "organizer@wustl.edu") do |u|
      u.name = "Tech Events Team"
      u.phone_number = "+1 (314) 935-5000"
      u.e_score = 0
    end

    category = EventCategory.find_or_create_by!(name: "Integration Test") do |ec|
      ec.icon = "test"
      ec.color = "#FF0000"
    end

    event = EventPost.find_or_create_by!(name: "Integration Test Event") do |ep|
      ep.description = "Integration test event for email delivery"
      ep.event_category = category
      ep.organizer = organizer
      ep.capacity = 25
      ep.event_time: 2.days.from_now
      ep.location_name = "Integration Test Location"
      ep.formatted_address = "456 Test Ave, St. Louis, MO"
    end

    registration = EventRegistration.find_or_create_by!(
      user: user,
      event_post: event
    ) do |er|
      er.status = :confirmed
    end

    puts "✅ Test data created"

    # 发送邮件
    expect {
      mail = EventNotificationMailer.enrollment_confirmation(registration)
      mail.deliver_now!
    }.to change { ActionMailer::Base.deliveries.count }.by(1)

    puts "✅ REAL EMAIL SENT SUCCESSFULLY!"
    puts "Recipient: jxinran@wustl.edu"
    puts "Time: #{Time.current}"
    puts "Please check the inbox of jxinran@wustl.edu"
  end
end
