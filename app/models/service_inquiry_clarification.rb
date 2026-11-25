# frozen_string_literal: true

# Information ANT Marine needs from the prospective client. The system never sends these:
# staff prepare the questions, contact the client through their own channel, and record
# that contact and the answer here.
class ServiceInquiryClarification < ApplicationRecord
  STATUSES = %w[prepared contacted_outside_system answered withdrawn].freeze
  AWAITING_STATUSES = %w[prepared contacted_outside_system].freeze
  CONTACT_CHANNELS = {
    "phone" => "Phone call",
    "email_outside_system" => "Email from your own mailbox",
    "in_person" => "In person",
    "other" => "Other"
  }.freeze
  RESPONSE_SOURCES = {
    "phone" => "Phone call",
    "email" => "Email",
    "in_person" => "In person",
    "other" => "Other"
  }.freeze
  LIMITS = { subject: 160, questions: 2000, prepared_message: 4000, response_text: 4000 }.freeze

  belongs_to :service_inquiry
  belongs_to :created_by_membership, class_name: "Membership"
  belongs_to :contacted_by_membership, class_name: "Membership", optional: true
  belongs_to :response_recorded_by_membership, class_name: "Membership", optional: true
  belongs_to :withdrawn_by_membership, class_name: "Membership", optional: true

  normalizes :subject, with: ->(value) { value.to_s.squish.presence }
  normalizes :questions, :prepared_message, :response_text, with: ->(value) { value.to_s.gsub("\r\n", "\n").strip.presence }

  validates :status, inclusion: { in: STATUSES }
  validates :subject, presence: { message: "Give the clarification a short subject." }
  validates :questions, presence: { message: "List the questions the client needs to answer." }
  validates :contact_channel, inclusion: { in: CONTACT_CHANNELS.keys }, allow_nil: true
  validates :response_source, inclusion: { in: RESPONSE_SOURCES.keys }, allow_nil: true
  validate :within_limits

  scope :awaiting_answer, -> { where(status: AWAITING_STATUSES) }
  scope :awaiting_client, -> { where(status: "contacted_outside_system") }

  def status_label
    case status
    when "prepared" then "Prepared — not sent to the client"
    when "contacted_outside_system" then "Client contacted — waiting for an answer"
    when "answered" then "Answer recorded"
    when "withdrawn" then "Withdrawn"
    end
  end

  def badge_variant
    { "prepared" => "ant-badge--blue", "contacted_outside_system" => "ant-badge--warn",
      "answered" => "ant-badge--good", "withdrawn" => "ant-badge--muted" }.fetch(status, "ant-badge--muted")
  end

  def awaiting_answer?
    AWAITING_STATUSES.include?(status)
  end

  def contact_channel_label
    CONTACT_CHANNELS[contact_channel]
  end

  def response_source_label
    RESPONSE_SOURCES[response_source]
  end

  private

    def within_limits
      LIMITS.each do |attribute, maximum|
        value = public_send(attribute)
        errors.add(attribute, "Keep this under #{maximum} characters.") if value && value.length > maximum
      end
    end
end
