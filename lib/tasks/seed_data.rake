namespace :db do
  desc "Clear all data from database"
  task clear_data: :environment do
    puts "🗑️  Clearing all data from database..."

    EventRegistration.destroy_all
    puts "   ✓ Cleared event registrations"

    EventPost.destroy_all
    puts "   ✓ Cleared event posts"

    EventCategory.destroy_all
    puts "   ✓ Cleared event categories"

    User.destroy_all
    puts "   ✓ Cleared users"

    puts "✅ Database cleared!"
  end

  desc "Seed database with dummy event data"
  task seed_events: :environment do
    puts "🎯 Running event seed task..."
    load Rails.root.join('db', 'seeds.rb')
  end

  desc "Reset database and reseed with fresh data"
  task reseed: :environment do
    puts "🔄 Resetting database..."
    Rake::Task['db:drop'].invoke
    Rake::Task['db:create'].invoke
    Rake::Task['db:migrate'].invoke
    Rake::Task['db:seed_events'].invoke
  end
end
