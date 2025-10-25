require 'rails_helper'

RSpec.describe EventNotificationMailer, type: :mailer do
  describe '#enrollment_confirmation' do
    let(:mock_user) do
      double('User', 
        email: 'jxinran@wustl.edu', 
        name: 'Jxinran Test',
        phone_number: '+1 (314) 935-5000'
      )
    end

    let(:mock_organizer) do
      double('User',
        name: 'Event Organizer',
        phone_number: '+1 (555) 123-4567'
      )
    end

    let(:mock_event) do
      double('EventPost',
        name: 'Test Event',
        description: 'Test event description',
        event_time: 3.days.from_now,
        location_name: 'Test Location',
        formatted_address: '123 Test Street, St. Louis, MO',
        google_maps_url: 'https://maps.example.com',
        organizer: mock_organizer
      )
    end

    let(:mock_registration) do
      double('EventRegistration',
        user: mock_user,
        event_post: mock_event,
        waitlisted?: false
      )
    end

    let(:mail) { EventNotificationMailer.enrollment_confirmation(mock_registration) }

    it 'sends to correct recipient' do
      expect(mail.to).to eq(['jxinran@wustl.edu'])
    end

    it 'has correct subject for confirmed enrollment' do
      expect(mail.subject).to eq('Event Enrollment Confirmation - Test Event')
    end

    it 'includes event details in email body' do
      body = mail.body.encoded
      expect(body).to include('Test Event')
      expect(body).to include('Test Location')
      expect(body).to include('Event Organizer')
    end

    it 'includes organizer phone number' do
      expect(mail.body.encoded).to include('+1 (555) 123-4567')
    end

    context 'when user is waitlisted' do
      let(:waitlisted_registration) do
        double('EventRegistration',
          user: mock_user,
          event_post: mock_event,
          waitlisted?: true
        )
      end

      let(:waitlisted_mail) { EventNotificationMailer.enrollment_confirmation(waitlisted_registration) }

      it 'has waitlist subject' do
        expect(waitlisted_mail.subject).to eq('Waitlist Confirmation - Test Event')
      end

      it 'includes waitlist information' do
        body = waitlisted_mail.body.encoded
        expect(body).to include('waitlist')
        expect(body).to include('Waitlist Confirmation')
      end
    end
  end
end
