# frozen_string_literal: true

module Commercial
  # Checks that a quotation is complete enough for internal review and approval.
  # Drafts may be saved incomplete; these rules apply only at submission and approval.
  class QuoteReadiness
    Issue = Data.define(:step, :field, :message)

    EMAIL_PATTERN = URI::MailTo::EMAIL_REGEXP
    PLACEHOLDER_TITLES = [ "new quotation" ].freeze

    def self.check(quote, on: Date.current)
      new(quote, on:).issues
    end

    def initialize(quote, on: Date.current)
      @quote = quote
      @revision = quote.current_revision
      @today = on
    end

    def ready?
      issues.empty?
    end

    def issues
      @issues ||= begin
        list = []
        if @revision.nil?
          list << Issue.new(step: 1, field: :base, message: "This quotation has no version to review.")
        else
          recipient_issues(list)
          scope_issues(list)
          pricing_issues(list)
          terms_issues(list)
        end
        list
      end
    end

    private

      def recipient_issues(list)
        if @quote.client_organization_id.blank? && @quote.prospective_value("company_name").strip.empty?
          list << Issue.new(step: 1, field: :client, message: "Choose a client organisation or enter the company name.")
        end
        if @quote.prospective_value("contact_name").strip.empty?
          list << Issue.new(step: 1, field: :contact_name, message: "Add the name of the person receiving this quotation.")
        end
        email = @quote.prospective_value("email").strip
        if email.empty?
          list << Issue.new(step: 1, field: :email, message: "Add the recipient's email address.")
        elsif !email.match?(EMAIL_PATTERN)
          list << Issue.new(step: 1, field: :email, message: "Check the recipient's email address.")
        end
      end

      def scope_issues(list)
        title = @revision.title.to_s.strip
        if title.empty? || PLACEHOLDER_TITLES.include?(title.downcase)
          list << Issue.new(step: 2, field: :title, message: "Give the quotation a clear title describing the work.")
        end
        list << Issue.new(step: 2, field: :scope_description, message: "Describe the scope of work.") if blank_text?(@revision.scope_description)
        list << Issue.new(step: 2, field: :deliverables, message: "List what the client will receive.") if blank_text?(@revision.deliverables)
        if blank_text?(@revision.exclusions)
          list << Issue.new(step: 2, field: :exclusions, message: "State what is not included. Write \"None\" if nothing is excluded.")
        end
      end

      def pricing_issues(list)
        unless Money.supported?(@revision.currency)
          list << Issue.new(step: 3, field: :currency, message: "Choose a supported currency.")
        end

        items = @revision.line_items.to_a
        if items.empty?
          list << Issue.new(step: 3, field: :line_items, message: "Add at least one pricing line.")
          return
        end

        items.each_with_index do |item, index|
          label = "Pricing line #{index + 1}"
          list << Issue.new(step: 3, field: :line_items, message: "#{label}: add a description.") if item.description.to_s.strip.empty?
          list << Issue.new(step: 3, field: :line_items, message: "#{label}: quantity must be greater than zero.") unless item.quantity.to_d.positive?
          expected = (item.quantity.to_d * item.unit_price_cents.to_i).round
          list << Issue.new(step: 3, field: :line_items, message: "#{label}: the line total is out of date. Save the pricing again.") if expected != item.line_total_cents
        end

        expected_total = items.sum(&:line_total_cents)
        if @revision.subtotal_cents != expected_total || @revision.total_cents != expected_total
          list << Issue.new(step: 3, field: :total, message: "The quotation total is out of date. Save the pricing again.")
        end
        list << Issue.new(step: 3, field: :total, message: "The quotation total must be greater than zero.") unless expected_total.positive?
      end

      def terms_issues(list)
        if @revision.valid_until.blank?
          list << Issue.new(step: 4, field: :valid_until, message: "Set the date this quotation is valid until.")
        elsif @revision.valid_until < @today
          list << Issue.new(step: 4, field: :valid_until, message: "The validity date has passed. Choose a future date.")
        end
        if blank_text?(@revision.payment_terms)
          list << Issue.new(step: 4, field: :payment_terms, message: "Add the payment terms agreed for this quotation.")
        end
      end

      def blank_text?(value)
        value.to_s.strip.empty?
      end
  end
end
