class Site < Sinatra::Base
  get "/get_prediction.json" do
    if (cp = CachedPrediction.where(listing_id: params[:listing_id]).first)
      cp.hits += 1
      cp.save!
      return {listing_id: params[:listing_id], predicted_price: cp.predicted_price}.to_json
    else
      if (raw_plane = RawPlane.where(listing_id: params[:listing_id]).first)
        cp = CachedPrediction.new(listing_id: params[:listing_id], raw_plane_id: raw_plane.id, predicted_price: raw_plane.predicted_price_python_load)
        cp.hits += 1
        cp.save!
        return {listing_id: params[:listing_id], predicted_price: cp.predicted_price}.to_json
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
end