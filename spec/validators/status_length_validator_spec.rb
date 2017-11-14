# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StatusLengthValidator do
  subject { Fabricate.build :status }

  before { stub_const 'StatusLengthValidator::MAX_CHARS', 100 }

  let(:over_limit_text) { 'a' * described_class::MAX_CHARS * 2 }

  context 'when status is remote' do
    before { subject.update! account: Fabricate(:account, domain: 'host.example') }

    it { is_expected.to allow_value(over_limit_text).for(:text) }
    it { is_expected.to allow_value(over_limit_text).for(:spoiler_text).against(:text) }
  end

  context 'when status is a local reblog' do
    before { subject.update! reblog: Fabricate(:status) }

    it { is_expected.to allow_value(over_limit_text).for(:text) }
    it { is_expected.to allow_value(over_limit_text).for(:spoiler_text).against(:text) }
  end

  context 'when text is over character limit' do
    it { is_expected.to_not allow_value(over_limit_text).for(:text).with_message(too_long_message) }

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
    end
  end

  context 'when content warning text is over character limit' do
    it { is_expected.to_not allow_value(over_limit_text).for(:spoiler_text).against(:text).with_message(too_long_message) }
  end

  context 'when text and content warning combine to exceed limit' do
    before { subject.text = 'a' * 50 }

    it { is_expected.to_not allow_value('a' * 55).for(:spoiler_text).against(:text).with_message(too_long_message) }
  end

  context 'when text has space separated linkable URLs' do
    let(:text) { [starting_string, example_link].join(' ') }

    it { is_expected.to allow_value(text).for(:text) }
  end

  context 'when text has non-separated URLs' do
    let(:text) { [starting_string, example_link].join }

    it { is_expected.to_not allow_value(text).for(:text).with_message(too_long_message) }
  end

  context 'with excessively long URLs' do
    let(:text) { "http://example.com/valid?#{'#foo?' * 1000}" }

    it { is_expected.to_not allow_value(text).for(:text).with_message(too_long_message) }

    it 'counts only the front part of remote usernames' do
      username = '@alice'
      chars = StatusLengthValidator::MAX_CHARS - 1 - username.length
      text   = ('a' * chars) + " #{username}@#{'b' * 30}.com"
      status = status_double(text: text)
    end

    it { is_expected.to_not allow_value(text).for(:text).with_message(too_long_message) }
  end

  context 'when remote account usernames cause limit excess' do
    let(:text) { ('a' * 75) + " @alice@#{'b' * 30}.com" }

    it { is_expected.to allow_value(text).for(:text) }
  end

  context 'when remote usernames are attached to long domains' do
    let(:text) { "@alice@#{'b' * Extractor::MAX_DOMAIN_LENGTH * 2}.com" }

    it { is_expected.to_not allow_value(text).for(:text).with_message(too_long_message) }
  end

  context 'with special character strings' do
    let(:multibyte_emoji) { '✨' * described_class::MAX_CHARS }
    let(:zwj_sequence) { '🏳️‍⚧️' * described_class::MAX_CHARS }

    it { is_expected.to allow_values(multibyte_emoji, zwj_sequence).for(:text) }
  end

  private

  def too_long_message
    I18n.t('statuses.over_character_limit', max: described_class::MAX_CHARS)
  end

  def starting_string
    'a' * 76
  end

  def example_link
    "http://#{'b' * 30}.com/example"
  end
end
