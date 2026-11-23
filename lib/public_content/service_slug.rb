# frozen_string_literal: true

module PublicContent
  module ServiceSlug
    MAX_BASE_LENGTH = 80
    RESERVED = %w[new edit index admin api staff client session].freeze

    module_function

    def generate(title:, organization:, except_id: nil)
      base = title.to_s.parameterize
      base = "service" if base.blank?
      base = base.delete_prefix("-").delete_suffix("-")
      base = base[0, MAX_BASE_LENGTH]
      base = "service" if base.blank?

      candidate = base
      suffix = 2
      scope = organization.services
      scope = scope.where.not(id: except_id) if except_id

      while reserved?(candidate) || scope.exists?(slug: candidate)
        candidate = "#{base}-#{suffix}"
        suffix += 1
      end

      candidate
    end

    def reserved?(slug)
      RESERVED.include?(slug) || slug.start_with?("staff", "client")
    end
  end
end
