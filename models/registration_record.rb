class RegistrationRecord
  include Mongoid::Document
  include Mongoid::Timestamps
  field :unique_id
  field :last_action_date
  field :content
end