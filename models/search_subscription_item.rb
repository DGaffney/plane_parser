class SearchSubscriptionItem
  include Mongoid::Document
  include Mongoid::Timestamps
  field :raw_plane_id
  field :search_subscription_id
  field :content
  field :item_type
  field :sent_at
end