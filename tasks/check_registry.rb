class CheckRegistry
  include Sidekiq::Worker
  sidekiq_options queue: :plane_collector
  def perform
    SaleChecker.new.check_plane_registry
    CheckRegistry.perform_in(60*60*24)
  end
end