# frozen_string_literal: true

module Authorization
  class PermissionCatalogue
    class UnknownKey < StandardError; end

    def self.all
      GeneratedPermissionDefinitions::RECORDS
    end

    def self.all_keys
      @all_keys ||= all.map { |r| r[:key] }.freeze
    end

    def self.fetch(key)
      find(key) || raise(UnknownKey, "Unknown permission key: #{key}")
    end

    def self.find(key)
      @by_key ||= all.index_by { |r| r[:key] }
      @by_key[key.to_s]
    end

    def self.known?(key)
      find(key).present?
    end

    def self.staff_applicable_keys
      @staff_applicable ||= all.select { |r| r[:domains].include?("staff") }.map { |r| r[:key] }.freeze
    end

    def self.client_applicable_keys
      @client_applicable ||= all.select { |r| r[:domains].include?("client") }.map { |r| r[:key] }.freeze
    end

    def self.applicable_keys_for_membership(membership)
      if membership.staff_domain?
        staff_applicable_keys
      elsif membership.client_domain?
        client_applicable_keys
      else
        []
      end
    end
  end
end
