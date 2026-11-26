# frozen_string_literal: true

require "test_helper"

class Delivery::CreateFromAcceptanceSecurityTest < ActiveSupport::TestCase
  setup do
    @staff = memberships(:ops_manager_membership)
    @client_org = organizations(:acme_client)
    @owner = memberships(:client_owner_membership)
    @quote = approve_quote!(create_ready_quote)
    @quote.update_columns(client_organization_id: @client_org.id)
    @release = Clients::ReleaseQuoteToPortal.call(
      actor_membership: @staff,
      quote: @quote,
      quote_revision: @quote.current_revision,
      client_organization: @client_org
    ).release
    @response = Commercial::QuoteDecision.call(
      membership: @owner,
      release: @release,
      response: "accepted",
      confirmation: true,
      idempotency_key: "f405-h1-sec-accept"
    ).response
  end

  test "unconfirmed creation is rejected" do
    assert_raises(Delivery::CreateFromAcceptance::Error) do
      Delivery::CreateFromAcceptance.call(membership: @staff, quote_response: @response, confirmation: false)
    end
    assert_equal 0, Project.where(quote_response_id: @response.id).count
  end

  test "request_changes response cannot create a project" do
    quote = approve_quote!(create_ready_quote)
    quote.update_columns(client_organization_id: @client_org.id)
    release = Clients::ReleaseQuoteToPortal.call(
      actor_membership: @staff, quote: quote,
      quote_revision: quote.current_revision, client_organization: @client_org
    ).release
    changed = Commercial::QuoteDecision.call(
      membership: @owner, release: release, response: "changes_requested",
      reason: "Clarify scope", confirmation: true, idempotency_key: "f405-h1-changes"
    ).response

    assert_raises(Delivery::CreateFromAcceptance::InvalidState) do
      Delivery::CreateFromAcceptance.call(membership: @staff, quote_response: changed, confirmation: true)
    end
  end

  test "staff without projects.create is denied" do
    surveyor = create_staff_membership!(role_key: "staff.surveyor")
    assert_raises(Delivery::CreateFromAcceptance::Denied) do
      Delivery::CreateFromAcceptance.call(membership: surveyor, quote_response: @response, confirmation: true)
    end
  end

  test "failed creation leaves no partial project rows" do
    before_projects = Project.count
    before_milestones = ProjectMilestone.count
    before_assignments = Assignment.count

    assert_raises(Delivery::CreateFromAcceptance::Error) do
      Delivery::CreateFromAcceptance.call(membership: @staff, quote_response: @response, confirmation: false)
    end

    assert_equal before_projects, Project.count
    assert_equal before_milestones, ProjectMilestone.count
    assert_equal before_assignments, Assignment.count
  end

  test "commercial snapshot rejects mutation via ActiveRecord" do
    project = Delivery::CreateFromAcceptance.call(
      membership: @staff, quote_response: @response, confirmation: true
    ).project
    project.commercial_snapshot = project.commercial_snapshot.merge("total_cents" => 1)
    assert_not project.valid?
    assert project.errors[:commercial_snapshot].any?
  end

  test "commercial snapshot rejects direct SQL mutation" do
    project = Delivery::CreateFromAcceptance.call(
      membership: @staff, quote_response: @response, confirmation: true
    ).project
    original_total = project.commercial_snapshot["total_cents"]
    assert_raises(ActiveRecord::StatementInvalid) do
      Project.transaction(requires_new: true) do
        Project.connection.execute(
          ActiveRecord::Base.sanitize_sql_array([
            "UPDATE projects SET commercial_snapshot = commercial_snapshot || '{\"total_cents\":1}'::jsonb WHERE id = ?",
            project.id
          ])
        )
      end
    end
    assert_equal original_total, project.reload.commercial_snapshot["total_cents"]
  end

  test "production environment rejects creation" do
    original = Delivery::CreateFromAcceptance.method(:available?)
    Delivery::CreateFromAcceptance.define_singleton_method(:available?) { false }
    begin
      assert_raises(Delivery::CreateFromAcceptance::Denied) do
        Delivery::CreateFromAcceptance.call(membership: @staff, quote_response: @response, confirmation: true)
      end
    ensure
      Delivery::CreateFromAcceptance.define_singleton_method(:available?, original)
    end
  end

  test "concurrent conversion yields a single project" do
    barrier = Queue.new
    errors = Queue.new
    results = Queue.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.pop
          begin
            result = Delivery::CreateFromAcceptance.call(
              membership: @staff, quote_response: @response, confirmation: true,
              attributes: { title: "Concurrent #{Thread.current.object_id}" }
            )
            results << result.project.id
          rescue StandardError => e
            errors << "#{e.class}: #{e.message}"
          end
        end
      end
    end

    2.times { barrier << true }
    threads.each(&:join)

    assert errors.empty?, "unexpected errors: #{Array.new(errors.size) { errors.pop }.join(', ')}"
    ids = Array.new(results.size) { results.pop }
    assert_equal 1, ids.uniq.size
    assert_equal 1, Project.where(quote_response_id: @response.id).count
  end
end
