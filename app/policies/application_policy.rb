# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :membership, :record

  def initialize(membership, record)
    @membership = membership
    @record = record
  end

  def effective_permissions
    @effective_permissions ||= Authorization::EffectivePermissions.new(membership)
  end

  class Scope
    attr_reader :membership, :scope

    def initialize(membership, scope)
      @membership = membership
      @scope = scope
    end

    def resolve
      scope
    end
  end

  def allowed?(permission_key)
    return false unless membership&.status == "active"

    effective_permissions.allowed?(permission_key)
  end
end
