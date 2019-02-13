class RawPlane
  include Mongoid::Document
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
  def self.get_predictions(filename="plane_preds2.csv")
    csv = CSV.open(filename, "w")
    RawPlane.where(:price.ne => 0).all.to_a.shuffle.collect{|rp| csv << [rp.make, rp.model, rp.category_level, rp.price, rp.predicted_price]}
    csv.close
  end

  def predicted_price
    RawPlaneObservation.where(raw_plane_id: self.id).first.predict_price rescue nil
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
      average_year = RawPlane.where(make: self.make, :model.in => self.similar_models).collect(&:year).collect(&:to_i).reject{|x| x == 0}.average.to_i
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
      return values.compact.empty? ? 0 : values.compact.reject(&:zero?).average
    else
      return values.compact.mode
    end
  end
  
  def disambiguated_avionics(avionic, limit=100)
    AvionicDisambiguator.disambiguation_candidates(avionic, limit)
  end
  
  def imputed_avionics
    self.avionics_package.collect{|av| GenerateAvionicsMatchRecord.new.perform(av) if AvionicsMatchRecord.where(given_name: av).first.nil? ; [av, AvionicsMatchRecord.where(given_name: av).first.likeliest_choice]}.select{|k,v| v.last > 0.5}.collect{|k,x| [x[0][1]["avionic_type"], x[0][1]["manufacturer"], x[0][1]["device"]]}
  end
  
  def imputed_results
    imputed_record.merge({
      "avionics_package" => imputed_avionics
    })
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
      imputed_results["last_updated"].strftime("%Y").to_i,
      imputed_results["last_updated"].strftime("%m").to_i,
      imputed_results["last_updated"].strftime("%w").to_i,
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
      imputed_results["similar_price"],
      (imputed_results["appraisal_range"][0] rescue 0),
      (imputed_results["appraisal_range"][1] rescue 0),
    ]}.merge(avionic_data: self.avionic_data(imputed_results, distinct_values), price: imputed_results["price"])
  end
end
