class Tweet
  include Mongoid::Document
  field :tweet_text
  field :tweet_type
  field :raw_plane_id
  field :tweet_sent, type: Boolean, default: false
  
  def send_tweet
    if !self.tweet_sent
      resp = Tweeter.send_tweet_api(tweet_text)
      self.tweet_sent = true if resp.class == Twitter::Tweet
      puts self.tweet_text
      self.save!
    end
  end

  def self.generate_tweet(plane, text, tweet_type)
    return nil if plane.valuation_text.nil?
    t = Tweet.where(raw_plane_id: plane.id, tweet_type: tweet_type).first || Tweet.new(raw_plane_id: plane.id, tweet_type: tweet_type)
    return nil if t.tweet_sent
    t.tweet_text = text
    t.save!
    t.send_tweet
    sleep(3)
  end

  def self.generate_reposted_posts
    RawPlane.where(:created_at.gte => Time.now-24*60*60).each do |plane|
      next if plane.reg_number == "Not Listed"
      other_counts = RawPlane.where(:reg_number => plane.reg_number).count-1
      if other_counts < 1000 && other_counts > 0 && plane.reg_number.length <= 6
        most_recent_price = RawPlane.where(:id.ne => plane.id, reg_number: plane.reg_number).collect{|x| [x.created_at, x.price]}.sort_by(&:first).reverse.first.last rescue nil
        pretty_most_recent_price = most_recent_price.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
        self.generate_tweet(
          plane,
          "Reposted plane alert: #{plane.year_make_model_text}#{plane.location_text} - plane has been reposted after previous price of $#{pretty_most_recent_price} and new registration is showing. #{plane.price_with_valuation_text}. Listing available here: #{plane.full_link}",
          "repost"
        )
      end
    end
  end

  def self.generate_sold_posts
    RawPlane.where(delisted: true, :archived_link.nin => ["", nil], :"latest_certficate_reissue_date.last_certificate_date".ne => nil).select{|x| t = (x.last_updated||x.id.generation_time); g = x.latest_certficate_reissue_date["last_certificate_date"]-t; g > 0 && g < 5*4*7*24*60*60}.each do |plane|
      self.generate_tweet(
        plane,
        "Sold plane alert: #{plane.year_make_model_text}#{plane.location_text} - plane is delisted and new registration is showing. #{plane.price_with_valuation_text}: archived listing available here: #{plane.archived_link}",
        "sold"
      )
    end
  end

  def self.generate_delisted_posts
    RawPlane.where(delisted: true, :archived_link.nin => ["", nil], :price.nin => [0, nil]).each do |plane|
      self.generate_tweet(
        plane,
        "Delisted plane alert: #{plane.year_make_model_text}#{plane.location_text} - post now offline. #{plane.price_with_valuation_text}: archived listing available here: #{plane.archived_link}",
        "delisted"
      )
    end
  end

  def self.generate_unique_plane_posts
    RawPlane.where(:created_at.gte => Time.now-60*60*24).each do |plane|
      if RawPlane.where(make: plane.make, model: plane.model).count == 1
        self.generate_tweet(
          plane,
          "Rare plane alert: #{plane.year_make_model_text}#{plane.location_text} - no other planes match this make/model. #{plane.price_with_valuation_text}: #{plane.full_link}",
          "unique"
        )
      end
    end
  end

  def self.generate_budget_posts
    RawPlane.where(:price.gt => 0, :price.lte => 30000, :created_at.gte => Time.now-60*60*24).each do |plane|
      self.generate_tweet(
        plane,
        "Cheap plane alert: #{plane.year_make_model_text}#{plane.location_text}. #{plane.price_with_valuation_text}: #{plane.full_link}",
        "budget"
      )
    end
  end

  def self.generate_deal_posts
     categories = ["Piston+Helicopters", "Turboprop", "Single+Engine+Piston", "Multi+Engine+Piston", "Ultralight", "Rotary+Wing", "Gliders+%7C+Sailplanes"]
     plane_ids = RawPlane.where(:delisted.ne => true, :deal_tweeted.ne => true, :last_updated.gte => Time.now-60*60*24*30, :category_level.in => categories, :image_count.gte => 2, :price.ne => 0).collect(&:id)
     predicted_prices = Hash[RawPlaneObservation.where(:raw_plane_id.in => plane_ids).collect{|x| [x.raw_plane_id, x.predict_price]}]
     deals = plane_ids.collect{|x| [RawPlane.find(x), RawPlane.find(x).price.to_f-predicted_prices[x].to_f]}.sort_by(&:last).select{|x| x.last.abs/x.first.price < 0.50 && x.last.abs/x.first.price > 0.05 && x.first.price < 300000 && x.last < 0}
     deals.each do |plane, savings|
       self.generate_tweet(
         plane,
         "Undervalued plane alert: #{plane.year_make_model_text}#{plane.location_text}. #{plane.price_with_valuation_text}: #{plane.full_link}",
         "deal"
       )
     end
   end

  def self.check_for_tweets_to_send
    puts "Checking for reposted listings..."
    Tweet.generate_reposted_posts
    puts "Checking for sold planes..."
    Tweet.generate_sold_posts
    puts "Checking for delisted listings..."
    Tweet.generate_delisted_posts
    puts "Checking for unique planes..."
    Tweet.generate_unique_plane_posts
    puts "Checking for cheap deals..."
    Tweet.generate_budget_posts
    puts "Checking for deal posts..."
    Tweet.generate_deal_posts
  end
end