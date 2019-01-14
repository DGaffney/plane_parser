class Tweeter
  def self.run
    while true
      self.identify_deals.each do |plane, savings|
        f = File.open(plane.id.to_s+".json", "w")
        f.write({tweet: self.tweet_text(plane, savings), username: SETTINGS["twitter_user"], password: SETTINGS["twitter_password"]}.to_json)
        f.close
        puts "python scripts/tweet.py #{plane.id.to_s}.json"
        results = JSON.parse(`python scripts/tweet.py #{plane.id.to_s}.json`) rescue nil
        puts results
        `rm #{plane.id.to_s}.json`
        `pkill chrome`
        if !results.nil?
          plane.deal_tweeted = true
          plane.save!
        end
      end
      sleep(60*60)
    end
  end
  
  def self.tweet_text(plane, savings)
    loc = plane.location && !plane.location.empty? ? " in #{plane.location}" : ""
    "#{plane.year} #{plane.make.capitalize} #{plane.model.capitalize}#{loc} -- $#{plane.price.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}, undervalued by ≈#{((savings.abs/plane.price).round(2)*100).to_i}% (posted #{plane._id.generation_time.strftime("%Y-%m-%d")}): https://trade-a-plane.com#{plane.link}"
  end
  
  def self.identify_deals
    categories = ["Piston+Helicopters", "Turboprop", "Single+Engine+Piston", "Multi+Engine+Piston", "Ultralight", "Rotary+Wing", "Gliders+%7C+Sailplanes"]
    plane_ids = RawPlane.where(:delisted.ne => true, :deal_tweeted.ne => true, :last_updated.gte => Time.now-60*60*24*30, :category_level.in => categories, :image_count.gte => 2, :price.ne => 0).collect(&:id)
    predicted_prices = Hash[RawPlaneObservation.where(:raw_plane_id.in => plane_ids).collect{|x| [x.raw_plane_id, x.predict_price]}]
    plane_ids.collect{|x| [RawPlane.find(x), RawPlane.find(x).price.to_f-predicted_prices[x].to_f]}.sort_by(&:last).select{|x| x.last.abs/x.first.price < 0.50 && x.last.abs/x.first.price > 0.05 && x.first.price < 300000 && x.last < 0}
  end
end
