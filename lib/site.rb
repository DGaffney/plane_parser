class Site < Sinatra::Base
  get "/get_prediction" do
    if (cp = CachedPrediction.where(listing_id: params[:listing_id]).first)
      cp.hits += 1
      cp.save!
      return {listing_id: params[:listing_id], predicted_price: cp.predicted_price}.to_json
    else
      if (raw_plane = RawPlane.where(listing_id: params[:listing_id]).first)
        cp = CachedPrediction.new(listing_id: params[:listing_id], raw_plane_id: raw_plane.id, predicted_price: raw_plane.predicted_price)
        cp.hits += 1
        cp.save!
        return {listing_id: params[:listing_id], predicted_price: cp.predicted_price}.to_json
      end
    end
    return {listing_id: params[:listing_id], error: "Plane not in database, sorry!"}
  end
end