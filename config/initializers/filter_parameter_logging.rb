# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :phone, :contact_name, :company_name, :company_website, :vessel_name, :project_name, :location,
  :description, :preferred_date, :form_stamp,
  :body, :note, :subject, :reason, :questions, :prepared_message, :response_text, :duplicate_reference, /\Aq\z/
]
