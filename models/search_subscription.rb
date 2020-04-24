class SearchSubscription
  include Mongoid::Document
  include Mongoid::Timestamps
  field :user_name
  field :user_email
  field :plan_id
  field :search_url
  field :customer_id
  field :subscription_id
  field :subscription_item_id
  field :subscription_title
  after_create :send_welcome_email

  def send_welcome_email
    Mailer.send_welcome_email(self)
  end
end