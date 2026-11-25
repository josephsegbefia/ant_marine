# frozen_string_literal: true

module PublicContent
  class HowWeWorkPresenter
    DEFAULT_LEDE = "One clear journey, start to finish. You always know where things stand and what happens next.".freeze

    DEFAULT_ASSURANCE_CARDS = [
      {
        title: "Conversation first",
        description: "We start with your goals and constraints before proposing any work."
      },
      {
        title: "Clear scope and quotation",
        description: "We confirm what is needed and provide a quotation where appropriate."
      },
      {
        title: "Written confirmation",
        description: "A preferred date is not a confirmed booking until ANT Marine agrees terms in writing."
      }
    ].freeze

    def initialize(page)
      @page = page
    end

    def lede
      @page.public_summary.presence || DEFAULT_LEDE
    end

    def process_steps
      from_data = @page.public_page_data["process_steps"]
      return normalize_steps(from_data) if from_data.present?

      HomepagePresenter::PROCESS_STEPS
    end

    def assurance_cards
      from_data = @page.public_page_data["assurance_cards"]
      return from_data if from_data.present?

      DEFAULT_ASSURANCE_CARDS.map(&:stringify_keys)
    end

    private

      def normalize_steps(steps)
        steps.map do |step|
          step = step.stringify_keys
          { title: step["title"], description: step["description"] }
        end
      end
  end
end