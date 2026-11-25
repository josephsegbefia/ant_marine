# frozen_string_literal: true

class ServiceInquiry < ApplicationRecord
  CHANNELS = %w[public_form contact_form client_portal staff].freeze
  STATUSES = %w[submitted under_review needs_clarification qualified unqualified merged closed].freeze
  OPEN_STATUSES = %w[submitted under_review needs_clarification qualified].freeze
  CLOSED_STATUSES = %w[unqualified merged closed].freeze
  CLOSE_REASONS = {
    "cancelled" => "Cancelled by the client",
    "not_proceeding" => "Client is no longer proceeding",
    "other" => "Other reason"
  }.freeze
  NOTE_LIMIT = 2000
  ORIGINAL_FIELDS = %w[organization_id reference_number channel service_id service_title_snapshot company_name contact_name
                       contact_email contact_phone project_name vessel_name location description preferred_date
                       submission_token submission_metadata submitted_at].freeze
  NOT_SURE = "not_sure"
  EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/
  PHONE_FORMAT = /\A[0-9+()\-. ]{6,32}\z/

  LIMITS = {
    company_name: 160,
    contact_name: 120,
    contact_email: 254,
    contact_phone: 32,
    project_name: 160,
    vessel_name: 120,
    location: 200,
    description: 4000
  }.freeze

  # Steps of the public wizard each field belongs to; used to reopen the right step after errors.
  FIELD_STEPS = {
    service_id: 1, project_name: 2, vessel_name: 2, location: 2, description: 2, preferred_date: 2,
    company_name: 3, contact_name: 3, contact_email: 3, contact_phone: 3
  }.freeze

  belongs_to :organization
  belongs_to :client_organization, class_name: "Organization", optional: true
  belongs_to :service, optional: true
  belongs_to :assigned_membership, class_name: "Membership", optional: true
  belongs_to :duplicate_of, class_name: "ServiceInquiry", optional: true
  has_many :quotes, dependent: :restrict_with_exception
  has_many :assignments, -> { order(:created_at, :id) }, class_name: "ServiceInquiryAssignment",
                                                          dependent: :restrict_with_exception
  has_many :notes, -> { order(:created_at, :id) }, class_name: "ServiceInquiryNote", dependent: :restrict_with_exception
  has_many :clarifications, -> { order(:created_at, :id) }, class_name: "ServiceInquiryClarification",
                                                             dependent: :restrict_with_exception
  has_many :duplicates, class_name: "ServiceInquiry", foreign_key: :duplicate_of_id,
                        inverse_of: :duplicate_of, dependent: :restrict_with_exception

  attribute :service_choice, :string

  normalizes :company_name, :contact_name, :project_name, :vessel_name, :location, with: ->(value) { value.to_s.squish.presence }
  normalizes :contact_email, with: ->(value) { value.to_s.strip.downcase.presence }
  normalizes :contact_phone, with: ->(value) { value.to_s.squish.presence }
  normalizes :description, with: ->(value) { value.to_s.gsub("\r\n", "\n").strip.presence }

  validates :reference_number, presence: true, uniqueness: true
  validates :channel, inclusion: { in: CHANNELS }
  validates :current_status, inclusion: { in: STATUSES }
  validates :submission_token, presence: true, uniqueness: true
  validates :company_name, presence: { message: "Enter your company or organisation name." }
  validates :contact_name, presence: { message: "Enter your name." }
  validates :contact_email, presence: { message: "Enter an email address so we can reply." }
  validates :contact_email, format: { with: EMAIL_FORMAT, message: "Enter a valid email address, like name@company.com." },
                            allow_blank: true
  validates :contact_phone, format: { with: PHONE_FORMAT, message: "Enter a phone number using digits, spaces and + only." },
                            allow_blank: true
  validates :location, presence: { message: "Tell us where the work will take place." }
  validates :description, presence: { message: "Describe what you need, in your own words." }
  validate :within_length_limits
  validate :service_choice_is_valid
  validate :preferred_date_is_not_in_the_past, if: :preferred_date_changed?
  validate :original_request_unchanged, on: :update
  validates :qualification_note, :closure_note, length: { maximum: NOTE_LIMIT }

  scope :recent_first, -> { order(submitted_at: :desc, id: :desc) }
  scope :open_requests, -> { where(current_status: OPEN_STATUSES) }
  scope :closed_or_resolved, -> { where(current_status: CLOSED_STATUSES) }
  scope :unassigned, -> { where(assigned_membership_id: nil) }

  def self.status_label(status)
    {
      "submitted" => "New",
      "under_review" => "Under review",
      "needs_clarification" => "Awaiting information",
      "qualified" => "Ready to quote",
      "unqualified" => "Outside our scope",
      "merged" => "Duplicate",
      "closed" => "Closed"
    }.fetch(status.to_s, status.to_s.humanize)
  end

  def status_label
    self.class.status_label(current_status)
  end

  def open?
    OPEN_STATUSES.include?(current_status)
  end

  def closed_or_resolved?
    CLOSED_STATUSES.include?(current_status)
  end

  def closure_reason_label
    case closure_reason
    when "outside_scope" then "Outside our service scope"
    when "duplicate" then "Duplicate of another enquiry"
    else CLOSE_REASONS[closure_reason]
    end
  end

  def requested_service_label
    service_title_snapshot.presence || "Not sure yet — needs advice"
  end

  def open_quote
    quotes.where.not(status: %w[withdrawn superseded]).order(:created_at).first
  end

  def first_error_step
    errors.attribute_names.filter_map { |name| FIELD_STEPS[name] || (name == :service_choice ? 1 : nil) }.min || 4
  end

  private

    def original_request_unchanged
      changed = ORIGINAL_FIELDS & changed_attribute_names_to_save
      errors.add(:base, "The original request cannot be changed.") if changed.any?
    end

    def within_length_limits
      LIMITS.each do |attribute, maximum|
        value = public_send(attribute)
        next if value.blank? || value.length <= maximum

        errors.add(attribute, "Keep this under #{maximum} characters.")
      end
    end

    def service_choice_is_valid
      return if service_choice.nil? && persisted?
      return if service_choice == NOT_SURE && service_id.nil?
      return if service.present? && service.status == "published" && service.organization_id == organization_id

      errors.add(:service_choice, "Choose a service from the list, or choose “I’m not sure yet”.")
    end

    def preferred_date_is_not_in_the_past
      return if preferred_date.blank?

      errors.add(:preferred_date, "Choose a date from today onwards, or leave it blank.") if preferred_date < Date.current
    end
end
