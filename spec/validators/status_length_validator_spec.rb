# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StatusLengthValidator do
  describe '#validate' do
    before { stub_const("#{described_class}::MAX_CHARS", 500) } # Example values below are relative to this baseline

    it 'does not add errors onto remote statuses' do
      status = instance_double(Status, local?: false)
      allow(status).to receive(:errors)

      subject.validate(status)

      expect(status).to_not have_received(:errors)
    end

    it 'does not add errors onto local reblogs' do
      status = instance_double(Status, local?: false, reblog?: true)
      allow(status).to receive(:errors)

      subject.validate(status)

      expect(status).to_not have_received(:errors)
    end

    it 'adds an error when content warning is over MAX_CHARS characters' do
      chars = StatusLengthValidator::MAX_CHARS + 1
      status = status_double(spoiler_text: 'a' * chars)
      subject.validate(status)
      expect(status.errors).to have_received(:add)
    end

    it 'adds an error when text is over MAX_CHARS characters' do
      chars = StatusLengthValidator::MAX_CHARS + 1
      status = status_double(text: 'a' * chars)
      subject.validate(status)
      expect(status.errors).to have_received(:add)
    end

    it 'adds an error when text and content warning are over MAX_CHARS characters total' do
      chars1 = 20
      chars2 = StatusLengthValidator::MAX_CHARS + 1 - chars1
      status = status_double(spoiler_text: 'a' * chars, text: 'b' *chars2)
      subject.validate(status)
      expect(status.errors).to have_received(:add)
    end

    it 'counts URLs as 23 characters flat' do
      chars = StatusLengthValidator::MAX_CHARS - 1 - 23
      text   = ('a' * chars) + " http://#{'b' * 30}.com/example"
      status = status_double(text: text)

      subject.validate(status)
      expect(status.errors).to_not have_received(:add)
    end

    it 'does not reduce calculated length of non-autolinkable URLs' do
      text = [starting_string, example_link].join
      status = status_double(text: text)

      subject.validate(status)
      expect(status.errors).to have_received(:add)
    end

    it 'does not reduce calculated length of count overly long URLs' do
      text = "http://example.com/valid?#{'#foo?' * 1000}"
      status = status_double(text: text)
      subject.validate(status)
      expect(status.errors).to have_received(:add)
    end

    it 'counts only the front part of remote usernames' do
      username = '@alice'
      chars = StatusLengthValidator::MAX_CHARS - 1 - username.length
      text   = ('a' * chars) + " #{username}@#{'b' * 30}.com"
      status = status_double(text: text)

      subject.validate(status)
      expect(status.errors).to_not have_received(:add)
    end

    it 'does count both parts of remote usernames for overly long domains' do
      text   = "@alice@#{'b' * 500}.com"
      status = status_double(text: text)

      subject.validate(status)
      expect(status.errors).to have_received(:add)
    end
  end

  private

  def starting_string
    'a' * 476
  end

  def example_link
    "http://#{'b' * 30}.com/example"
  end

  def status_double(spoiler_text: '', text: '')
    instance_double(
      Status,
      spoiler_text: spoiler_text,
      text: text,
      errors: activemodel_errors,
      local?: true,
      reblog?: false
    )
  end

  def activemodel_errors
    instance_double(ActiveModel::Errors, add: nil)
  end
end
