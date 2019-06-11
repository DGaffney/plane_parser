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

  def self.generate_sold_posts
    RawPlane.where(delisted: true, :archived_link.nin => ["", nil], :"latest_certficate_reissue_date.last_certificate_date".ne => nil).select{|x| t = (x.last_updated||x.id.generation_time); g = t-x.latest_certficate_reissue_date["last_certificate_date"]; g > 0 && g < 5*4*7*24*60*60}.each do |plane|
      if Tweet.where(raw_plane_id: plane.id, tweet_type: "sold").first.nil?
        t = Tweet.new(raw_plane_id: plane.id, tweet_type: "sold")
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
        t = Tweet.new(raw_plane_id: plane.id, tweet_type: "delisted")
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
        t = Tweet.new(raw_plane_id: plane.id, tweet_type: "budget")
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
    Tweet.generate_sold_posts
    Tweet.generate_delisted_posts
    Tweet.generate_budget_posts
  end
end