# Clear existing data (development only)
if Rails.env.development?
  puts "🗑️  Clearing existing data..."
  EventRegistration.destroy_all
  EventPost.destroy_all
  EventCategory.destroy_all
  User.destroy_all
end

puts "🌱 Seeding database..."

# Create Users
puts "Creating users..."
users = [
  User.create!(name: "Alice Chen", email: "alice@university.edu", password: "password123", password_confirmation: "password123", phone_number: "555-0101", e_score: 150),
  User.create!(name: "Bob Martinez", email: "bob@university.edu", password: "password123", password_confirmation: "password123", phone_number: "555-0102", e_score: 120),
  User.create!(name: "Charlie Kim", email: "charlie@university.edu", password: "password123", password_confirmation: "password123", phone_number: "555-0103", e_score: 200),
  User.create!(name: "Diana Patel", email: "diana@university.edu", password: "password123", password_confirmation: "password123", phone_number: "555-0104", e_score: 80),
  User.create!(name: "Ethan Brown", email: "ethan@university.edu", password: "password123", password_confirmation: "password123", phone_number: "555-0105", e_score: 95)
]

# Create Event Categories
puts "Creating event categories..."
categories = {
  sports: EventCategory.create!(name: "Sports & Recreation"),
  social: EventCategory.create!(name: "Social & Networking"),
  academic: EventCategory.create!(name: "Academic & Career"),
  food: EventCategory.create!(name: "Food & Dining"),
  arts: EventCategory.create!(name: "Arts & Culture"),
  gaming: EventCategory.create!(name: "Gaming & Esports")
}

# Create Event Posts
puts "Creating events..."
events = [
  EventPost.create!(
    name: "Intramural Soccer Pickup Game",
    description: "Casual soccer game, all skill levels welcome! Bring your own water.",
    location_name: "University Sports Field",
    event_time: 2.days.from_now.change(hour: 16),
    capacity: 22,
    organizer: users[2],
    event_category: categories[:sports]
  ),

  EventPost.create!(
    name: "Friday Night Pizza Party",
    description: "Free pizza in the quad! Come hang out and meet new people.",
    location_name: "Student Center Quad",
    event_time: 3.days.from_now.change(hour: 19),
    capacity: 50,
    organizer: users[0],
    event_category: categories[:food]
  ),

  EventPost.create!(
    name: "Study Group: Data Structures",
    description: "Collaborative study session for CS201. Bring your laptop and questions!",
    location_name: "Library Room 305",
    event_time: 1.day.from_now.change(hour: 14),
    capacity: 15,
    organizer: users[3],
    event_category: categories[:academic]
  ),

  EventPost.create!(
    name: "Open Mic Night",
    description: "Showcase your talent! Musicians, poets, comedians all welcome. Sign up at the door.",
    location_name: "Campus Coffee House",
    event_time: 5.days.from_now.change(hour: 20),
    capacity: 40,
    organizer: users[1],
    event_category: categories[:arts]
  ),

  EventPost.create!(
    name: "League of Legends Tournament",
    description: "5v5 tournament, prizes for top 3 teams! Registration closes 1 hour before start.",
    location_name: "Computer Lab C",
    event_time: 4.days.from_now.change(hour: 18),
    capacity: 30,
    organizer: users[4],
    event_category: categories[:gaming]
  ),

  EventPost.create!(
    name: "Career Fair Networking Mixer",
    description: "Meet recruiters from top tech companies in a casual setting. Business casual attire.",
    location_name: "Alumni Hall",
    event_time: 7.days.from_now.change(hour: 17),
    capacity: 100,
    organizer: users[0],
    event_category: categories[:academic]
  ),

  EventPost.create!(
    name: "Beach Volleyball Meetup",
    description: "Chill beach volleyball session. Beginners encouraged!",
    location_name: "Campus Beach Courts",
    event_time: 6.days.from_now.change(hour: 15),
    capacity: 16,
    organizer: users[2],
    event_category: categories[:sports]
  )
]

# Create Event Registrations
puts "Creating event registrations..."
[
  [users[0], events[0]],
  [users[1], events[0]],
  [users[3], events[0]],
  [users[0], events[2]],
  [users[1], events[3]],
  [users[2], events[3]],
  [users[3], events[3]],
  [users[4], events[4]],
  [users[0], events[4]],
  [users[1], events[5]]
].each do |user, event|
  EventRegistration.create!(user: user, event_post: event, status: :confirmed, registered_at: Time.current)
end

puts "✅ Seeding complete!"
puts "📊 Created:"
puts "   - #{User.count} users"
puts "   - #{EventCategory.count} categories"
puts "   - #{EventPost.count} events"
puts "   - #{EventRegistration.count} registrations"
