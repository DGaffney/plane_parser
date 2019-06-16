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
      self.save!
    end
  end

  def self.generate_deal_posts
    categories = ["Piston+Helicopters", "Turboprop", "Single+Engine+Piston", "Multi+Engine+Piston", "Ultralight", "Rotary+Wing", "Gliders+%7C+Sailplanes"]
    plane_ids = RawPlane.where(:delisted.ne => true, :deal_tweeted.ne => true, :last_updated.gte => Time.now-60*60*24*30, :category_level.in => categories, :image_count.gte => 2, :price.ne => 0).collect(&:id)
    predicted_prices = Hash[RawPlaneObservation.where(:raw_plane_id.in => plane_ids).collect{|x| [x.raw_plane_id, x.predict_price]}]
    deals = plane_ids.collect{|x| [RawPlane.find(x), RawPlane.find(x).price.to_f-predicted_prices[x].to_f]}.sort_by(&:last).select{|x| x.last.abs/x.first.price < 0.50 && x.last.abs/x.first.price > 0.05 && x.first.price < 300000 && x.last < 0}
    deals.each do |plane, savings|
      t = Tweet.where(raw_plane_id: plane.id, tweet_type: "deal").first || Tweet.new(raw_plane_id: plane.id, tweet_type: "deal")
      loc = plane.location && !plane.location.empty? ? " in #{plane.location}" : ""
      t.tweet_text = "#{plane.year} #{plane.make.capitalize} #{plane.model.capitalize}#{loc} -- $#{plane.price.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}, undervalued by ≈#{((savings.abs/plane.price).round(2)*100).to_i}% (posted #{plane._id.generation_time.strftime("%Y-%m-%d")}): https://trade-a-plane.com#{plane.link}"
      t.save!
      t.send_tweet
    end
  end

  def self.generate_sold_posts
    RawPlane.where(delisted: true, :archived_link.nin => ["", nil], :"latest_certficate_reissue_date.last_certificate_date".ne => nil).select{|x| t = (x.last_updated||x.id.generation_time); g = x.latest_certficate_reissue_date["last_certificate_date"]-t; g > 0 && g < 5*4*7*24*60*60}.each do |plane|
      if Tweet.where(raw_plane_id: plane.id, tweet_type: "sold").first.nil?
        t = Tweet.where(raw_plane_id: plane.id, tweet_type: "sold").first || Tweet.new(raw_plane_id: plane.id, tweet_type: "sold")
        loc = plane.location && !plane.location.empty? ? " in #{plane.location}" : ""
        predicted_price = RawPlaneObservation.where(raw_plane_id: plane.id).first.predict_price rescue nil
        next if predicted_price.nil?
        residual = plane.price.to_i-predicted_price
        residual_pct = residual/plane.price.to_i
        next if residual_pct.abs > 0.40
        valuation_text = "#{residual > 0 ? "undervalued" : "overvalued"} by #{((residual_pct).round(2)*100).to_i}%"
        t.tweet_text = "#{plane.year} #{plane.make.capitalize} #{plane.model.capitalize}#{loc} possibly sold - delisted and new registration -- archived listing: #{plane.archived_link}. Was priced at $#{plane.price.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} (#{valuation_text})"
        t.save!
        t.send_tweet
      end
    end
  end

  def self.generate_delisted_posts
    RawPlane.where(delisted: true, :archived_link.nin => ["", nil], :price.nin => [0, nil]).each do |plane|
      if Tweet.where(raw_plane_id: plane.id, tweet_type: "delisted").first.nil?
        t = Tweet.where(raw_plane_id: plane.id, tweet_type: "delisted").first || Tweet.new(raw_plane_id: plane.id, tweet_type: "delisted")
        loc = plane.location && !plane.location.empty? ? " in #{plane.location}" : ""
        predicted_price = RawPlaneObservation.where(raw_plane_id: plane.id).first.predict_price rescue nil
        next if predicted_price.nil?
        residual = plane.price.to_i-predicted_price
        residual_pct = residual/plane.price.to_i
        next if residual_pct.abs > 0.40
        valuation_text = "#{residual > 0 ? "undervalued" : "overvalued"} by #{((residual_pct).round(2)*100).to_i}%"
        t.tweet_text = "#{plane.year} #{plane.make.capitalize} #{plane.model.capitalize}#{loc} delisted -- archived listing: #{plane.archived_link}. Was priced at $#{plane.price.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} (#{valuation_text})"
        t.save!
        t.send_tweet
      end
    end
  end

  def self.generate_budget_posts
    RawPlane.where(:price.gt => 0, :price.lte => 30000, :created_at.gte => Time.now-60*60*24).each do |plane|
      if Tweet.where(raw_plane_id: plane.id, tweet_type: "budget").first.nil?
        t = Tweet.where(raw_plane_id: plane.id, tweet_type: "budget").first || Tweet.new(raw_plane_id: plane.id, tweet_type: "budget")
        loc = plane.location && !plane.location.empty? ? " in #{plane.location}" : ""
        predicted_price = RawPlaneObservation.where(raw_plane_id: plane.id).first.predict_price rescue nil
        next if predicted_price.nil?
        residual = plane.price.to_i-predicted_price
        residual_pct = residual/plane.price.to_i
        next if residual_pct.abs > 0.40
        valuation_text = "#{plane.price.to_i < predicted_price ? "undervalued" : "overvalued"} by #{(((residual_pct).round(2)*100).to_i).abs}%"
        t.tweet_text = "Cheap plane alert: #{plane.year} #{plane.make.capitalize} #{plane.model.capitalize}#{loc}. Priced at $#{plane.price.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} (#{valuation_text}): https://trade-a-plane.com#{plane.link}"
        t.save!
        t.send_tweet
      end
    end
  end

  def self.check_for_tweets_to_send
    Tweet.generate_deal_posts
    Tweet.generate_sold_posts
    Tweet.generate_delisted_posts
    Tweet.generate_budget_posts
  end
end