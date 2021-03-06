class RawPlane
  include Mongoid::Document
  field :created_at, type: Time
  field :deal_tweeted, type: Boolean, default: false
  field :last_updated, type: Time
  field :region
  field :locality
  field :full_address
  field :price, type: Float
  field :make
  field :model
  field :year, type: Integer
  field :reg_number
  field :serial_no
  field :location
  field :avionics_package
  field :image_count
  field :condition
  field :flight_rules
  field :link
  field :archived_link
  field :listing_id
  field :category_level
  field :total_time, type: Float
  field :num_of_seats, type: Float
  field :engine_1_time
  field :prop_1_time
  field :year_painted
  field :interior_year
  field :engine_2_time
  field :useful_load
  field :prop_2_time
  field :fractional_ownership
  field :delisted
  field :latest_certficate_reissue_date
  field :header_image
  def predicted_stock_in_days(days=90)
    times = self.similar_planes.collect(&:created_at).sort
    per_day = times.count / ((times.last-times.first)/(60*60*24))
    {average_per_timeframe: per_day*days, probability_of_stock_in_timeframe: 1-Distribution::Poisson.pdf(0, per_day*days), timeframe: days}
  end

  def self.get_predictions(filename="plane_preds2.csv")
    csv = CSV.open(filename, "w")
    RawPlane.where(:price.ne => 0).all.to_a.shuffle.collect{|rp| csv << [rp.make, rp.model, rp.category_level, rp.price, rp.predicted_price]}
    csv.close
  end

  def location_text
    self.location && !self.location.empty? ? " in #{self.location}" : ""
  end

  def year_make_model_text
    "#{self.year.to_i == 0 ? "" : self.year} #{self.make.capitalize} #{self.model.capitalize}"
  end

  def pretty_price
    self.price.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def full_link
    "https://trade-a-plane.com#{self.link}"
  end
  
  def post_time
    (self.created_at || self._id.generation_time).strftime("%Y-%m-%d")
  end

  def valuation_text
    predicted_price = self.predicted_price
    return nil if predicted_price.nil?
    residual = self.price.to_i-predicted_price
    residual_pct = residual.abs/self.price.to_f
    return nil if residual_pct.abs > 0.40
    "#{residual > 0 ? "overvalued" : "undervalued"} by #{((residual_pct).round(2)*100).to_i}%"
  end

  def price_with_valuation_text
    valuation_text = self.valuation_text
    if valuation_text.nil?
      "Priced at $#{self.pretty_price}"
    else
      "Priced at $#{self.pretty_price}, #{self.valuation_text}"
    end
  end

  def predicted_price
    RawPlaneObservation.where(raw_plane_id: self.id).first.predict_price rescue nil
  end

  def predicted_price_python_load
    RawPlaneObservation.where(raw_plane_id: self.id).first.predict_price(false, true) rescue nil
  end

  def plane_online?
    page_data = Nokogiri.parse(RestClient::Request.execute(:url => "https://trade-a-plane.com"+self.link, :method => :get, :verify_ssl => false));false
    page_data.search("title").text.include?(self.listing_id)
  end

  def imputed_record
    similar_planes = self.similar_planes.to_a
    record = self.to_hash.merge(Hash[self.empty_fields.collect do |field|
      [field, determine_likeliest_value(field, similar_planes.collect{|x| x.send(field)})]
    end].merge(similar_price: similar_planes.collect(&:price).collect(&:to_i).reject(&:zero?).average))
    record["appraisal_range"] = appraisal_range(record)
    record
  end
  
  def appraisal_range(imputed_record)
    Appraiser.likely_appraisal_for_imputed_record(imputed_record)[-1]
  end

  def to_hash
    Hash[self.fields.keys.collect{|f| [f, self.send(f)]}]
  end

  def empty_fields
    Hash[self.fields.collect{|k,v| [k, self.send(k)]}.select{|k,v| self.bad_value(k,v)}].keys
  end

  def bad_value(field,value)
    if ["price", "year", "interior_year", "exterior_year"].include?(field)
      value.nil? || value.to_f.zero?
    else
      value.nil?
    end
  end

  def similar_models
    if RawPlane.where(make: self.make).count > 10 and RawPlane.where(make: self.make, model: self.model).count <= 10
      model_counts = RawPlane.where(make: self.make, :id.ne => self.id).collect(&:model).counts
      similarities = Hash[model_counts.collect{|alter, count| [alter, String::Similarity.cosine(self.model, alter)]}]
      cur_count = 0
      models = []
      similarities.collect{|k,v| [k, v/similarities.values.max+model_counts[k]/model_counts.values.sum]}.sort_by{|k,v| v}.reverse.each do |model, score|
        cur_count += model_counts[model]
        models << model
        break if cur_count > 10
      end
      return models
    elsif RawPlane.where(make: self.make).count <= 10
      return RawPlane.where(make: self.make).collect(&:model).uniq
    elsif RawPlane.where(make: self.make, model: self.model).count > 10
      return [self.model]
    end
  end

  def similar_years
    if self.year && self.year.to_i != 0
      return (self.year-3).upto((self.year+3)).to_a
    else
      average_years = RawPlane.where(make: self.make, :model.in => self.similar_models).collect(&:year).collect(&:to_i).reject{|x| x == 0}
      average_years = RawPlane.where(make: self.make).collect(&:year).collect(&:to_i).reject{|x| x == 0} if average_years.empty?
      average_years = RawPlane.where(:year.nin => ["0", 0, nil]).only(:year).collect(&:year).reject{|x| x == 0} if average_years.empty?
      average_year = average_years.average.to_i
      return (average_year-3).upto((average_year+3)).to_a
    end
  end
  
  def similar_planes
    RawPlane.where(make: self.make).and(RawPlane.or({:model.in => self.similar_models}, {:year.in => self.similar_years}).selector)
  end
  
  def determine_likeliest_value(field, values)
    if ["price", "total_time", "num_seats", "engine_1_time", "prop_1_time", "engine_2_time", "prop_2_time", "year_painted", "interior_year", "useful_load"].include?(field)
      return values.compact.empty? ? 0 : values.compact.collect(&:to_i).average
    elsif field == "year"
      return values.compact.reject(&:zero?).empty? ? 0 : values.compact.reject(&:zero?).average
    else
      return values.compact.mode
    end
  end
  
  def disambiguated_avionics(avionic, limit=100)
    AvionicDisambiguator.disambiguation_candidates(avionic, limit)
  end
  
  def imputed_avionics
    NewAvionicsMatchRecord.generate(self.avionics_package)
    NewAvionicsMatchRecord.where(:given_name.in => self.avionics_package, :probability.gte => 0.5).collect(&:resolved_avionic)
  end
  
  def old_imputed_avionics
    self.avionics_package.collect{|av| GenerateAvionicsMatchRecord.new.perform(av) if AvionicsMatchRecord.where(given_name: av).first.nil? ; [av, AvionicsMatchRecord.where(given_name: av).first.likeliest_choice]}.select{|k,v| v.last > 0.5}.collect{|k,x| [x[0][1]["avionic_type"], x[0][1]["manufacturer"], x[0][1]["device"]]}
  end
  
  def imputed_results
    imputed_record.merge({
      "avionics_package" => imputed_avionics
    })
  end

  def future_outlook(days=90)
    obs = RawPlane.where(:price.nin => [nil, 0.0], make: self.make, model: self.model, :year.gte => self.year-10, :year.lte => self.year+10, :created_at.gte => Time.now-60*60*24*365*2).order(:created_at.asc).to_a
    if obs.to_a.length < 10
      obs = self.similar_planes.select{|x| x.created_at > Time.now-60*60*24*365} 
    end
    low = obs.collect(&:price).percentile(0.15)
    high = obs.collect(&:price).percentile(0.85)
    x, y = obs.select{|r| r.price > low && r.price < high}.collect{|r| [(r.created_at-obs.first.created_at)/(60*60*24), r.price]}.transpose
    lineFit = LineFit.new
    return nil if x.nil? || x.to_a.length == 1
    lineFit.setData(x,y)
    intercept, slope = lineFit.coefficients
  	residuals = lineFit.residuals
    r2 = lineFit.rSquared
    if r2 > 0.2 && x.to_a.length > 8
      return {future_value: ((slope * days) / y.average).percent, days_out: days, future_error: (residuals.collect(&:abs).median / y.average).percent}
    else
      return {error: "No discernible trend - market is stable right now."}
    end
  end

  def self.distinct_values
    @@distinct_values ||= BSON::Document.new({
      category_level: RawPlane.distinct(:category_level),
      region: RawPlane.distinct(:region),
      make: RawPlane.distinct(:make),
      model: RawPlane.distinct(:model),
      condition: RawPlane.distinct(:model),
      flight_rules: RawPlane.distinct(:flight_rules),
      avionic_avionic_type: AvionicDisambiguator.avionics_manifest.keys,
      avionic_manufacturer: AvionicDisambiguator.avionics_manifest.values.collect(&:keys).flatten.uniq,
      avionic_device: AvionicDisambiguator.avionics_manifest.values.collect(&:values).flatten.uniq,
    })
  end

  def self.avionic_data(imputed_results, distinct_values)
    imputed_results["avionics_package"].collect{|x| 
      [
        distinct_values[:avionic_avionic_type].index(x[0]), 
        distinct_values[:avionic_manufacturer].index(x[1]), 
        distinct_values[:avionic_device].index(x[2])
      ]
    }.transpose.collect(&:counts)
  end

  def self.transform_to_row(imputed_results, distinct_values)
    {base_record: [
      (imputed_results["last_updated"]||Time.now).strftime("%Y").to_i,
      (imputed_results["last_updated"]||Time.now).strftime("%m").to_i,
      (imputed_results["last_updated"]||Time.now).strftime("%w").to_i,
      distinct_values[:region].index(imputed_results["region"])||-1,
      distinct_values[:category_level].index(imputed_results["category_level"])||-1,
      distinct_values[:make].index(imputed_results["make"])||-1,
      distinct_values[:model].index(imputed_results["model"])||-1,
      imputed_results["year"].to_i,
      imputed_results["image_count"],
      distinct_values[:condition].index(imputed_results["condition"])||-1,
      distinct_values[:category_level].index(imputed_results["category_level"])||-1,
      imputed_results["total_time"].to_i,
      imputed_results["num_of_seats"].to_i,
      imputed_results["engine_1_time"].to_i,
      imputed_results["prop_1_time"].to_i,
      imputed_results["year_painted"].to_i,
      imputed_results["interior_year"].to_i,
      imputed_results["engine_2_time"].to_i,
      imputed_results["useful_load"].to_i,
      imputed_results["prop_2_time"].to_i, 
      imputed_results["similar_price"]||imputed_results[:similar_price],
      (imputed_results["appraisal_range"][0] rescue 0),
      (imputed_results["appraisal_range"][1] rescue 0),
    ]}.merge(avionic_data: self.avionic_data(imputed_results, distinct_values), price: imputed_results["price"])
  end
  
  def self.generate_make_model_variations
    make_models = RawPlane.only(:make, :model).collect{|k| [k.make, k.model]};false
    csv = CSV.open("model_name_variations.csv", "w")
    i = 0
    make_models.each do |make, model|
      i += 1
      puts i
      makes = [AvionicDisambiguator.avionic_substring_generator(make), AvionicDisambiguator.avionic_substring_generator(make.downcase), AvionicDisambiguator.avionic_substring_generator(make.split(" ").collect(&:capitalize).join(" "))].flatten
      models = [AvionicDisambiguator.avionic_substring_generator(model), AvionicDisambiguator.avionic_substring_generator(model.downcase), AvionicDisambiguator.avionic_substring_generator(model.split(" ").collect(&:capitalize).join(" "))].flatten
      makes.each do |m|
        models.each do |mm|
          f = m+" "+mm
          csv << [f] if f.gsub(" ", "").length > 4
          f = mm+" "+m
          csv << [f] if f.gsub(" ", "").length > 4
        end
      end
    end;false
    csv.close
  end
end
