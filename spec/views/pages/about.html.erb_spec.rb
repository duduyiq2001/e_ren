require 'rails_helper'

RSpec.describe 'pages/about.html.erb', type: :view do
  let(:current_user) { create(:user, name: "Test User") }

  before do
    without_partial_double_verification do
      allow(view).to receive(:current_user).and_return(current_user)
      allow(view).to receive(:logged_in?).and_return(true)
    end
    render
  end

  it 'displays the E-Ren title' do
    expect(rendered).to include('E-Ren')
  end

  it 'explains what E-Score is' do
    expect(rendered).to include('What is E-Score')
    expect(rendered).to include('Extraversion')
  end

  it 'explains how to earn E-Score' do
    expect(rendered).to include('How to Earn E-Score')
    expect(rendered).to include('Attend Events')
    expect(rendered).to include('Host Events')
    expect(rendered).to include('Confirm Attendance')
  end

  it 'explains how events work' do
    expect(rendered).to include('How Events Work')
    expect(rendered).to include('Browse or Create')
    expect(rendered).to include('Register')
  end

  it 'has navigation links' do
    expect(rendered).to have_link('Browse Events', href: root_path)
    expect(rendered).to have_link('View Leaderboard', href: leaderboard_path)
  end
end
