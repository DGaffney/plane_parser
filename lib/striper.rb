require "stripe"
class Striper
  def initialize
    Stripe::Product.retrieve(SETTINGS["email_subscription_product_id"])
  end
end