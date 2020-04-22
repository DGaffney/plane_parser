class EmailSubscription
  include Mongoid::Document
  include Mongoid::Timestamps
  field :email_id
end