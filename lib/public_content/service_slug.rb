# frozen_string_literal: true

module PublicContent
  module ServiceSlug
    RESERVED = %w[new edit index admin api staff client session insights projects training resources].freeze

    module_function

    def generate(title:, organization:, except_id: nil)
      ContentSlug.generate(
        title: title,
        scope: organization.services,
        except_id: except_id
      )
    end

    def reserved?(slug)
      RESERVED.include?(slug) || slug.start_with?("staff", "client")
    end
  end
end
