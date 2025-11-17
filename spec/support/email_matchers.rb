# Custom RSpec matchers for email testing

RSpec::Matchers.define :have_sent_email do |expected_count = nil|
  match do |block|
    @before_count = ActionMailer::Base.deliveries.count
    block.call
    @after_count = ActionMailer::Base.deliveries.count
    @sent_count = @after_count - @before_count

    if expected_count
      @sent_count == expected_count
    else
      @sent_count > 0
    end
  end

  failure_message do
    if expected_count
      "expected to send #{expected_count} email(s), but sent #{@sent_count}"
    else
      "expected to send at least one email, but sent #{@sent_count}"
    end
  end

  supports_block_expectations
end

RSpec::Matchers.define :have_sent_email_to do |email_address|
  match do |block|
    @before_count = ActionMailer::Base.deliveries.count
    block.call
    @after_count = ActionMailer::Base.deliveries.count

    if @after_count > @before_count
      last_email = ActionMailer::Base.deliveries.last
      last_email.to.include?(email_address)
    else
      false
    end
  end

  failure_message do
    if @after_count <= @before_count
      "expected to send an email, but no email was sent"
    else
      last_email = ActionMailer::Base.deliveries.last
      "expected email to be sent to #{email_address}, but it was sent to #{last_email.to}"
    end
  end

  supports_block_expectations
end

RSpec::Matchers.define :have_sent_email_with_subject do |subject_pattern|
  match do |block|
    @before_count = ActionMailer::Base.deliveries.count
    block.call
    @after_count = ActionMailer::Base.deliveries.count

    if @after_count > @before_count
      last_email = ActionMailer::Base.deliveries.last
      last_email.subject.match?(subject_pattern)
    else
      false
    end
  end

  failure_message do
    if @after_count <= @before_count
      "expected to send an email, but no email was sent"
    else
      last_email = ActionMailer::Base.deliveries.last
      "expected email subject to match #{subject_pattern}, but got '#{last_email.subject}'"
    end
  end

  supports_block_expectations
end

