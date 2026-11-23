# frozen_string_literal: true

Authorization::CatalogueSeeder.seed!
PublicContent::CatalogueSeeder.seed! if Organization.exists?(kind: "ant_marine")
