# frozen_string_literal: true

# macOS + pg: forked Solid Queue children must not inherit ActiveRecord/libpq
# handles from a multi-threaded parent (see DiagnosticReports "multi-threaded
# process forked" / PQconnectStart segfault).
Rails.application.config.to_prepare do
  next unless defined?(SolidQueue::Processes::Supervised)

  SolidQueue::Processes::Supervised.prepend(Module.new do
    def create_fork(&block)
      release_database_connections_before_fork

      fork do
        register_signal_handlers
        block.call
        exit!(0)
      end
    end

    private

      def release_database_connections_before_fork
        return unless defined?(ActiveRecord::Base)

        ActiveRecord::Base.connection_handler.clear_all_connections!(:all)
      end
  end)
end
