# frozen_string_literal: true

module Authorization
  class CatalogueSeeder
    CATALOGUE_VERSION = 1

    @seeded = false

    def self.seed!
      return if catalogue_present?

      new.seed!
      @seeded = true
    end

    def self.reset_seed_flag!
      @seeded = false
    end

    def self.catalogue_present?
      expected = GeneratedPermissionDefinitions::RECORDS.size
      Permission.count >= expected && RolePermission.exists?
    end

    def seed!
      Permission.transaction do
        seed_permissions!
        seed_role_permissions!
      end
    end

    private

      def seed_permissions!
        GeneratedPermissionDefinitions::RECORDS.each do |row|
          domain = row[:domains].size > 1 ? "both" : row[:domains].first
          permission = Permission.find_or_initialize_by(key: row[:key])
          permission.assign_attributes(
            display_name: row[:display],
            description: row[:explanation],
            category: row[:category],
            domain: domain,
            override_rule: row[:override_rule],
            catalogue_version: CATALOGUE_VERSION
          )
          permission.save!
        end
      end

      def seed_role_permissions!
        RoleDefaults.all_role_keys.each do |role_key|
          keys = RoleDefaults.keys_for(role_key)
          by_key = Permission.where(key: keys).index_by(&:key)
          missing = keys - by_key.keys
          raise "Missing permission keys for #{role_key}: #{missing.join(', ')}" if missing.any?

          keys.each do |key|
            RolePermission.find_or_create_by!(role_key: role_key, permission: by_key.fetch(key))
          end
        end
      end
  end
end
