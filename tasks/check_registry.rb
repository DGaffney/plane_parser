class CheckRegistry
  include Sidekiq::Worker
  sidekiq_options queue: :plane_collector
  def perform(raw_plane_id=nil)
    if raw_plane_id.nil?
      SaleChecker.new.planes_to_check.each do |id|
        CheckRegistry.perform_async(id)
      end
      CheckRegistry.perform_in(60*60*24)
    else
      SaleChecker.new.check_plane_registry(raw_plane_id)
    end
  end
end