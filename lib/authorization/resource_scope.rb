# frozen_string_literal: true

module Authorization
  # Phase 4 resource checks (projects, assignments, documents) attach here.
  module ResourceScope
    module_function

    def allows?(*)
      false
    end
  end
end
