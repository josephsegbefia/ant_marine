# frozen_string_literal: true

module PublicContent
  module ContentSlug
    MAX_BASE_LENGTH = 80
    RESERVED = ServiceSlug::RESERVED

    module_function

    def generate(title:, scope:, except_id: nil)
      base = title.to_s.parameterize
      base = "content" if base.blank?
      base = base.delete_prefix("-").delete_suffix("-")
      base = base[0, MAX_BASE_LENGTH]
      base = "content" if base.blank?

      candidate = base
      suffix = 2
      relation = scope
      relation = relation.where.not(id: except_id) if except_id

      while reserved?(candidate) || relation.exists?(slug: candidate)
        candidate = "#{base}-#{suffix}"
        suffix += 1
      end

      candidate
    end

    def reserved?(slug)
      ServiceSlug.reserved?(slug)
    end
  end
end
