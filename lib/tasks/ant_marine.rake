# frozen_string_literal: true

namespace :ant_marine do
  desc "Provision ANT Marine internal organisation and first Super Administrator (development only). " \
       "Requires ANT_MARINE_BOOTSTRAP_EMAIL and ANT_MARINE_BOOTSTRAP_PASSWORD."
  task bootstrap_super_admin: :environment do
    unless Rails.env.development? || Rails.env.test?
      abort "bootstrap_super_admin is only allowed in development or test."
    end

    email = ENV.fetch("ANT_MARINE_BOOTSTRAP_EMAIL") { ENV["EMAIL"] }
    password = ENV.fetch("ANT_MARINE_BOOTSTRAP_PASSWORD") { ENV["PASSWORD"] }

    if email.blank? || password.blank?
      abort "Set ANT_MARINE_BOOTSTRAP_EMAIL and ANT_MARINE_BOOTSTRAP_PASSWORD (or EMAIL and PASSWORD)."
    end

    email = email.strip.downcase

    org = Organization.find_by(kind: "ant_marine")
    if org
      puts "ANT Marine organisation already exists: #{org.name} (#{org.slug})"
    else
      org = Organization.create!(
        kind: "ant_marine",
        name: ENV.fetch("ANT_MARINE_ORG_NAME", "ANT Marine W.A."),
        slug: ENV.fetch("ANT_MARINE_ORG_SLUG", "ant-marine"),
        status: "active"
      )
      puts "Created ANT Marine organisation: #{org.slug}"
    end

    user = User.find_by(email: email)
    if user
      puts "User already exists for #{email}; password and role are unchanged."
    else
      user = User.create!(email: email, password: password, status: "active", email_verified_at: Time.current)
      puts "Created user #{email}"
    end

    membership = Membership.find_by(user: user, organization: org)
    if membership
      if membership.role_key != "staff.super_administrator"
        puts "Membership exists with role #{membership.role_key}; not promoting to super administrator."
      else
        puts "Super Administrator membership already present."
      end
    else
      Membership.create!(
        user: user,
        organization: org,
        role_key: "staff.super_administrator",
        status: "active",
        accepted_at: Time.current
      )
      puts "Created Super Administrator membership."
    end
  end
end
