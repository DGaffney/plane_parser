class Site < Sinatra::Base
  post "/create_subscription.json" do
    post_params = JSON.parse(request.body.read).symbolize_keys
    subscription = SearchSubscription.new(
      user_name: post_params[:name],
      user_email: post_params[:email],
      plan_id: post_params[:planId],
      search_url: post_params[:searchUrl],
      customer_id: post_params[:subscription]["customer"],
      subscription_id: post_params[:subscription]["id"],
      subscription_item_id: post_params[:subscription]["items"]["data"][0]["id"],
      subscription_title: post_params[:subscription]["plan"]["nickname"]
    )
    subscription.save!
    return subscription.to_json
  end

  post "/parse_search_page.json" do
    body_params = JSON.parse(request.body.read)
    search_url = URI.parse(URI.decode(body_params["search_url"])) rescue nil
    return {error: "Error! Can't parse url that looks like: #{body_params["search_url"]}. Please provide a Trade-A-Plane search results URL"}.to_json if search_url.nil? || !search_url.host.include?("trade-a-plane.com")
    return {error: "Please provide a Trade-A-Plane search URL"}.to_json if search_url.path != "/search"
    return {error: "Please provide a Trade-A-Plane search URL for aircraft only - this search doesn't look to be for aircraft."}.to_json if !search_url.query.include?("s-type=aircraft")
    return {search_params: URI.decode_www_form(search_url.query), search_url: search_url.to_s}.to_json
  end

  get "/get_prediction.json" do
    if (cp = CachedPrediction.where(listing_id: params[:listing_id]).first)
      cp.hits += 1
      cp.save!
      return {listing_id: params[:listing_id], predicted_price: cp.predicted_price}.to_json
    else
      if (raw_plane = RawPlane.where(listing_id: params[:listing_id]).first)
        result = raw_plane.predicted_price_python_load rescue nil
        if result
          cp = CachedPrediction.new(listing_id: params[:listing_id], raw_plane_id: raw_plane.id, predicted_price: result)
          cp.hits += 1
          cp.save!
          return {listing_id: params[:listing_id], predicted_price: cp.predicted_price}.to_json
        else
          return {listing_id: params[:listing_id], error: "Model failed to yield a response! Message /u/dgaff on Reddit or @tap_deals on Twitter to flag this issue."}.to_json
        end
      end
    end
    return {listing_id: params[:listing_id], error: "Plane not in database, sorry!"}.to_json
  end
  
  get "/get_listing_ids.json" do
    since_time = Time.parse(params[:since_time]) rescue nil
    parse_error = since_time.nil?
    since_time ||= Time.now-60*60*24*7
    return {since_time: since_time, used_since_time_default: parse_error, listing_ids: RawPlane.where(:created_at.gte => since_time).distinct(:listing_id)}.to_json
  end
  
  get "/search_subscriptions_by_id.json" do
    search_subscriptions = SearchSubscription.all_by_one_id(params[:id])
    if search_subscriptions
      return search_subscriptions.to_json
    else
      return {error: "Couldn't find a subscription with that ID."}.to_json
    end
  end
  
  get "/set_subscription_cadence.json" do
    return {error: "Cadence can only be daily or weekly!"}.to_json if !["daily", "weekly"].include?(params[:cadence])
    search_subscriptions = SearchSubscription.all_by_one_id(params[:id])
    search_subscriptions.each do |ss|
      ss.email_cadence = params[:cadence]
      ss.save!
    end
    return {success: true}.to_json
  end

  get "/unsubscribe.json" do
    ss = SearchSubscription.find(params[:id])
    ss.deactivate
    return {success: true}.to_json
  end
end