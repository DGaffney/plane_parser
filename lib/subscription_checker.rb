class SubscriptionChecker
  def self.parsed_page(url)
    Nokogiri.parse(RestClient::Request.execute(:url => url, :method => :get, :verify_ssl => false))
  end
  def self.parsed_id(link)
    URI.decode_www_form(link.attributes["href"].value).select{|att| att.first == "listing_id"}.first.last
  end

  def self.listing_ids(url)
    begin
      self.parsed_page(url).search("a#title").collect{|link| self.parsed_id(link)}
    rescue RestClient::TooManyRequests
      sleep(4)
      retry
    end
  end

  def self.check_url(search_subscription)
    listing_ids = self.listing_ids(search_subscription.search_url)
    RawPlane.where(:listing_id.in => listing_ids).each do |raw_plane|
      if SearchSubscriptionItem.where(item_type: "search_result", "content.raw_plane_id": raw_plane.id, search_subscription_id: search_subscription.id).first.nil?
        pred_price = raw_plane.predicted_price
        if pred_price
          item_content = {
            predicted_stock: raw_plane.predicted_stock_in_days,
            actual_percentile: raw_plane.similar_planes.collect(&:price).reverse_percentile(raw_plane.price),
            expected_percentile: raw_plane.similar_planes.collect(&:price).reverse_percentile(pred_price),
            predicted_price: pred_price,
            link: raw_plane.link,
            text: raw_plane.year_make_model_text,
            raw_plane_id: raw_plane.id,
            price: raw_plane.price
          }
          SearchSubscriptionItem.new(
            search_subscription_id: search_subscription.id,
            content: item_content,
            item_type: "search_result",
          ).save!
        end
      end
    end
  end
  
  def self.check_subscriptions
    SearchSubscription.active.each do |ss|
      SubscriptionChecker.check_url(ss)
    end
    SearchSubscription.active.each do |ss|
      ss.send_subscription_email
    end
  end
end