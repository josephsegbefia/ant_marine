class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM", "ANT Marine W.A. <no-reply@localhost>") }
  layout "mailer"
end
