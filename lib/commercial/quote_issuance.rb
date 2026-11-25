# frozen_string_literal: true

module Commercial
  # Issuing a quotation to a client is gated until F4-02B provides verified delivery
  # (or an approved manual-issuance record). Until then approved quotations stay
  # "approved — not yet sent" and nothing claims the client received them.
  module QuoteIssuance
    UNAVAILABLE_MESSAGE = "Sending quotations to clients is not available yet. " \
                          "The approved PDF can be downloaded for internal use."

    module_function

    def available?
      false
    end
  end
end
