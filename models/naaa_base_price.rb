class RawPlaneObservation#.train_model
include Mongoid::Document
field :raw_plane_id, type: BSON::ObjectId
field :base_record, type: Array
end