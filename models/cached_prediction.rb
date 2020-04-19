class CachedPrediction
  include Mongoid::Document
  include Mongoid::Timestamps
  field :listing_id, type: String
  field :raw_plane_id, type: BSON::ObjectId
  field :hits, type: Integer, default: 0
  field :predicted_price, type: Float
end