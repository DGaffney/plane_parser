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
  field :email_cadence, default: "daily"
  field :last_sent_at
  field :deactivated_at
  after_create :send_welcome_email
  def self.active
    SearchSubscription.where(deactivated_at: nil)
  end

  def self.active_daily
    self.active.where(email_cadence: "daily")
  end

  def send_subscription_email
    sss = SearchSubscription.all_by_one_id(self.id)
    if (self.email_cadence == "daily" && self.last_sent_at.nil? || self.last_sent_at < Time.now-60*60*24) || (self.email_cadence == "weekly" && self.last_sent_at.nil? || self.last_sent_at < Time.now-60*60*24*7)
      ssis = SearchSubscriptionItem.where(sent_at: nil, :search_subscription_id.in =>  sss.collect(&:id))
      if ssis.count > 0
        Mailer.send_subscription_email(self, ssis)
        ssis.each do |item|
          item.sent_at = self.last_sent_at
          item.save!
        end
        self.last_sent_at = Time.now
        self.save!
        sss.each do |ss|
          ss.last_sent_at = Time.now
          ss.save!
        end
      end
    end
  end

  def send_welcome_email
    Mailer.send_welcome_email(self)
  end
  
  def self.all_by_one_id(id)
    search_subscription = SearchSubscription.find(id) rescue nil
    if search_subscription
      return SearchSubscription.active.where(user_email: search_subscription.user_email)
    else
      return nil
    end
  end

  def deactivate
    begin
      Stripe::Subscription.delete(self.subscription_id)
    rescue
      print("Error on deactivation")
    end
    self.deactivated_at = Time.now
    self.save!
  end
  
  def add_tweet_item(tweet)
    SearchSubscriptionItem.new(
      raw_plane_id: tweet.raw_plane_id,
      search_subscription_id: self.id,
      content: {tweet: tweet.tweet_text, link: RawPlane.find(tweet.raw_plane_id).link},
      item_type: "pending_tweet",
    ).save!
  end
end