# frozen_string_literal: true

# Dev-only screenshot capture for F4-05-H1. Writes to tmp/f405_h1_screens/ (gitignored).
# Usage: bin/rails runner script/f405_h1_screenshots.rb

require "capybara"
require "selenium-webdriver"
require "fileutils"

notes = Rails.root.join("tmp/f405_h1_screens/NOTES.txt")
abort "Missing #{notes}" unless notes.exist?

data = notes.read.lines.to_h { |line| line.strip.split("=", 2) }
staff_email = data.fetch("staff_reviewer")
client_email = data.fetch("client")
password = data.fetch("password")
project_id = data.fetch("project_id")

out = Rails.root.join("tmp/f405_h1_screens")
FileUtils.mkdir_p(out)

Capybara.register_driver :h1_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--window-size=1440,900")
  options.add_argument("--disable-gpu")
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

session = Capybara::Session.new(:h1_chrome)
session.visit("http://127.0.0.1:3000/session/new")

def sign_in(session, email, password)
  session.visit("http://127.0.0.1:3000/session/new")
  session.fill_in "Work email", with: email
  session.fill_in "Password", with: password
  session.click_on "Sign in"
end

def shot(session, name, width)
  session.driver.browser.manage.window.resize_to(width, 900)
  sleep 0.4
  path = Rails.root.join("tmp/f405_h1_screens/#{name}_#{width}.png")
  session.save_screenshot(path.to_s)
  puts "wrote #{path.basename}"
end

sign_in(session, staff_email, password)
session.visit("http://127.0.0.1:3000/staff/projects")
[ 1440, 1280, 768, 390 ].each { |w| shot(session, "staff_projects_index", w) }

session.visit("http://127.0.0.1:3000/staff/projects/#{project_id}")
[ 1440, 1280, 768, 390 ].each { |w| shot(session, "staff_project_overview", w) }

session.visit("http://127.0.0.1:3000/staff/projects/#{project_id}?tab=team")
shot(session, "staff_project_team", 1280)
shot(session, "staff_project_team", 390)

session.visit("http://127.0.0.1:3000/staff/projects/#{project_id}?tab=tasks")
shot(session, "staff_project_tasks", 1280)

session.visit("http://127.0.0.1:3000/staff/projects/#{project_id}?tab=milestones")
shot(session, "staff_project_milestones", 1280)

session.visit("http://127.0.0.1:3000/staff/projects/#{project_id}?tab=schedule")
shot(session, "staff_project_schedule", 1280)

session.visit("http://127.0.0.1:3000/staff/tasks")
shot(session, "staff_my_tasks", 1280)
shot(session, "staff_my_tasks", 390)

session.visit("http://127.0.0.1:3000/session")
session.driver.browser.manage.delete_all_cookies

sign_in(session, client_email, password)
session.visit("http://127.0.0.1:3000/client/projects")
[ 1440, 1280, 768, 390 ].each { |w| shot(session, "client_projects_index", w) }

session.visit("http://127.0.0.1:3000/client/projects/#{project_id}")
[ 1440, 1280, 768, 390 ].each { |w| shot(session, "client_project_detail", w) }

session.driver.quit
puts "done"
