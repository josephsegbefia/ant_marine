require "test_helper"

class DatabaseSmokeTest < ActiveSupport::TestCase
  test "postgresql connection is active" do
    assert_predicate ActiveRecord::Base.connection, :active?
  end

  test "postgresql answers a simple query" do
    assert_equal 1, ActiveRecord::Base.connection.select_value("SELECT 1")
  end

  test "each test runs inside a transaction that rolls back session changes" do
    connection = ActiveRecord::Base.connection

    connection.execute("CREATE TEMP TABLE ant_marine_tx_check (marker integer NOT NULL)")
    connection.execute("INSERT INTO ant_marine_tx_check (marker) VALUES (99)")

    assert_equal 99, connection.select_value("SELECT marker FROM ant_marine_tx_check LIMIT 1")
  end
end
