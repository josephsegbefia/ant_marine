# frozen_string_literal: true

module StorageTestHelper
  def upload_storage_proof!(membership:, bytes:, filename: "poc.txt", classification: "standard")
    asset = nil
    perform_enqueued_jobs only: ScanStorageAssetJob do
      result = Storage::ProofUpload.call(
        membership: membership,
        organization: membership.organization,
        filename: filename,
        io: StringIO.new(bytes),
        classification: classification
      )
      asset = result.asset
    end
    asset.reload
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  include StorageTestHelper
  include ActiveJob::TestHelper
end
