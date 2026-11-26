# frozen_string_literal: true

class Invoice < ApplicationRecord
  ISSUE_STATUSES = %w[draft issued void].freeze
  MODES = %w[simulated].freeze
  PAYMENT_METHODS = %w[bank_transfer cash cheque mobile_money other].freeze

  belongs_to :operating_organization, class_name: "Organization"
  belongs_to :client_organization, class_name: "Organization"
  belongs_to :project
  belongs_to :quote
  belongs_to :quote_revision
  belongs_to :quote_response
  belongs_to :created_by_membership, class_name: "Membership"
  belongs_to :issued_by_membership, class_name: "Membership", optional: true
  belongs_to :voided_by_membership, class_name: "Membership", optional: true
  belongs_to :storage_asset, class_name: "Storage::Asset", optional: true

  has_many :invoice_line_items, -> { order(:position, :id) }, dependent: :restrict_with_exception, inverse_of: :invoice
  has_many :invoice_releases, dependent: :restrict_with_exception
  has_many :payment_records, dependent: :restrict_with_exception

  validates :reference_number, presence: true, uniqueness: true
  validates :mode, inclusion: { in: MODES }
  validates :issue_status, inclusion: { in: ISSUE_STATUSES }
  validates :currency, inclusion: { in: Commercial::Money::MINOR_UNITS.keys }
  validates :total_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validate :organizations_match_project
  validate :commercial_source_matches_project

  scope :draft, -> { where(issue_status: "draft") }
  scope :issued, -> { where(issue_status: "issued") }
  scope :voided, -> { where(issue_status: "void") }
  scope :not_void, -> { where.not(issue_status: "void") }
  scope :simulated, -> { where(mode: "simulated") }
  scope :for_operating_organization, ->(org) { where(operating_organization_id: org.id) }
  scope :for_client_organization, ->(org) { where(client_organization_id: org.id) }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def simulated?
    mode == "simulated"
  end

  def draft?
    issue_status == "draft"
  end

  def issued?
    issue_status == "issued"
  end

  def void?
    issue_status == "void"
  end

  def issue_status_label
    case issue_status
    when "draft" then "Draft"
    when "issued" then "Issued"
    when "void" then "Void"
    else issue_status.humanize
    end
  end

  def net_paid_cents
    payment_records.sum(&:net_amount_cents)
  end

  def outstanding_cents
    return 0 unless issued?

    [ total_cents - net_paid_cents, 0 ].max
  end

  def payment_status
    return "void" if void?
    return "draft" if draft?
    return "paid" if outstanding_cents.zero?
    return "partially_paid" if net_paid_cents.positive?

    "unpaid"
  end

  def payment_status_label
    case payment_status
    when "draft" then "Draft"
    when "unpaid" then "Unpaid"
    when "partially_paid" then "Partially paid"
    when "paid" then "Paid"
    when "void" then "Void"
    else payment_status.humanize
    end
  end

  def overdue?
    issued? && outstanding_cents.positive? && due_on.present? && due_on < Time.zone.today
  end

  def active_release
    invoice_releases.active.order(released_at: :desc).first
  end

  def released_to_client?
    active_release.present?
  end

  def display_total
    Commercial::Money.display(total_cents, currency)
  end

  def display_outstanding
    Commercial::Money.display(outstanding_cents, currency)
  end

  private

    def organizations_match_project
      return if project.blank?

      if operating_organization_id != project.operating_organization_id
        errors.add(:operating_organization, "must match the project operating organisation")
      end
      if client_organization_id != project.client_organization_id
        errors.add(:client_organization, "must match the project client organisation")
      end
    end

    def commercial_source_matches_project
      return if project.blank?

      errors.add(:quote, "must match the project commercial source") if quote_id != project.quote_id
      errors.add(:quote_revision, "must match the project commercial source") if quote_revision_id != project.quote_revision_id
      errors.add(:quote_response, "must match the project commercial source") if quote_response_id != project.quote_response_id
    end
end
