class GenerateRawPlaneObservation
  include Sidekiq::Worker
  sidekiq_options queue: :generate_rpo
  def perform(id)
    RawPlaneObservation.generate_from_raw_plane(RawPlane.find(id))
  end
end