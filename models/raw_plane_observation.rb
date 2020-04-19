class RawPlaneObservation#.train_model
  pyimport :pickle
  pyfrom :sklearn, import: :datasets
  pyfrom :'sklearn.model_selection', import: :train_test_split
  pyfrom :'sklearn.ensemble', import: :RandomForestRegressor
  include Mongoid::Document
  field :raw_plane_id, type: BSON::ObjectId
  field :base_record, type: Array
  field :avionic_data, type: Array
  field :price, type: Float
  
  def self.generate_from_raw_plane(rp)
    rpo = RawPlaneObservation.where({raw_plane_id: rp.id}).first
    rpo = RawPlaneObservation.new({raw_plane_id: rp.id}) if rpo.nil?
    rpo.update_attributes(RawPlane.transform_to_row(rp.imputed_results, RawPlane.distinct_values))
    rpo.save!
    rpo
  end
  
  def self.generate_for_all_planes
    (RawPlane.pluck(:id)-RawPlaneObservation.pluck(:raw_plane_id)).shuffle.each do |id|
      GenerateRawPlaneObservation.perform_async(id)
    end
  end

  def self.merge_hashes(hash_group)
    merged = {}
    hash_group.each do |hg|
      hg.each do |k,v|
        merged[k] ||= 0
        merged[k] += v
      end
    end
    merged.reject{|k,v| v < 5}
  end

  def self.bootstrap(obs, count)
    out_rows = []
    while out_rows.length < count
      out_rows << obs[(rand*obs.length).to_i]
    end
    out_rows
  end

  def self.get_model_data(avionic_type_keys, manufacturer_keys, device_keys, planes=RawPlaneObservation.all.to_a, include_appraisal=false, include_avionics=true)
    dataset = []
    prices = []
    planes.each do |plane|
      row = plane.base_record.dup.collect(&:to_f).collect{|x| x.nan? ? 0 : x}
      if !include_appraisal
        row[21] = 0
        row[22] = 0
      end
      if include_avionics
        avionic_type_keys.each do |key|
          row << ((plane.avionic_data[0][key]||0) rescue 0)
        end
        manufacturer_keys.each do |key|
          row << ((plane.avionic_data[1][key]||0) rescue 0)
        end
        device_keys.each do |key|
          row << ((plane.avionic_data[2][key]||0) rescue 0)
        end
      end
      dataset << row
      prices << plane.price
    end
    return dataset, prices
  end

  def self.generate_dataset(include_appraisal=false, include_avionics=true)
    all_planes = RawPlaneObservation.where(:raw_plane_id.in => RawPlane.where(:category_level => "Single+Engine+Piston", :price.lte => 150000).collect(&:id), :price.ne => 0).all.to_a.shuffle#.select{|rp| rp.year.to_i != 0 && rp.year < 1985}.collect(&:id), :price.ne => 0).all.to_a.shuffle
    all_planes = RawPlaneObservation.where(:raw_plane_id.in => RawPlane.all.collect(&:id), :price.ne => 0, :price.gte => 10000, :price.lte => 10000000).all.to_a.shuffle#.select{|rp| rp.year.to_i != 0 && rp.year < 1985}.collect(&:id), :price.ne => 0).all.to_a.shuffle
    avionic_types, manufacturers, devices = all_planes.collect(&:avionic_data).reject(&:empty?).transpose
    avionic_type_keys = RawPlaneObservation.merge_hashes(avionic_types).keys
    manufacturer_keys = RawPlaneObservation.merge_hashes(manufacturers).keys
    device_keys = RawPlaneObservation.merge_hashes(devices).keys
    x, y = RawPlaneObservation.get_model_data(avionic_type_keys, manufacturer_keys, device_keys, all_planes, include_appraisal)
    dataset_file = File.open("dataset.json", "w")
    dataset_file.write({"x": x, "y": y}.to_json)
    dataset_file.close
  end
  def self.train_model(include_appraisal=false, include_avionics=true)
    all_planes = RawPlaneObservation.where(:raw_plane_id.in => RawPlane.where(:category_level => "Single+Engine+Piston", :price.lte => 150000).collect(&:id), :price.ne => 0).all.to_a.shuffle#.select{|rp| rp.year.to_i != 0 && rp.year < 1985}.collect(&:id), :price.ne => 0).all.to_a.shuffle
    all_planes = RawPlaneObservation.where(:raw_plane_id.in => RawPlane.all.collect(&:id), :price.ne => 0).all.to_a.shuffle#.select{|rp| rp.year.to_i != 0 && rp.year < 1985}.collect(&:id), :price.ne => 0).all.to_a.shuffle
    binding.pry
    avionic_types, manufacturers, devices = all_planes.collect(&:avionic_data).reject(&:empty?).transpose
    avionic_type_keys = self.merge_hashes(avionic_types).keys
    manufacturer_keys = self.merge_hashes(manufacturers).keys
    device_keys = self.merge_hashes(devices).keys
    x, y = self.get_model_data(avionic_type_keys, manufacturer_keys, device_keys, all_planes, include_appraisal)
    x_train, x_test, y_train, y_test  = train_test_split(x,y, test_size: 0.2, random_state: Time.now.to_i)
    x_train, y_train = self.bootstrap([x_train, y_train.collect{|yt| yt+(rand-0.5)*yt*0.1}].transpose, 8000).transpose;false
    model = RandomForestRegressor.new(n_estimators=50)
    # model = AdaBoostRegressor.new()
    # model = BaggingRegressor.new()
    model.fit(x_train, y_train.collect{|v| Math.log(v)})
    diffs = model.predict(x_test).tolist().collect{|v| Math.exp(v)}.zip(y_test)
    puts diffs.to_json
    puts diffs.collect{|x| Math.sqrt((x[0]-x[1])**2)}.average
    puts model.score(x_test, y_test.collect{|v| Math.log(v)})
    model.fit(x, y)
    pickled = pickle.dumps(model);false
    f = File.open("raw_plane_observation_model#{include_appraisal ? "_full" : "_no_appraisal"}.pkl", "w")
    f.write(pickled)
    f.close
    f = File.open("raw_plane_observation_avionic_keys.json", "w")
    f.write([avionic_type_keys, manufacturer_keys, device_keys].to_json)
    f.close
    return model
  end

  def self.get_model(include_appraisal=false)
    puts "loading model..."
    @@current_raw_plane_observation_model ||= pickle.loads(open("raw_plane_observation_model#{include_appraisal ? "_full" : "_no_appraisal"}.pkl").read)
    puts "model Loaded"
    @@current_raw_plane_observation_model
  end

  def self.stored_avionics_keys
    @@stored_avionic_key_data ||= JSON.parse(File.read("raw_plane_observation_avionic_keys.json"))
  end

  def predict_price(include_appraisal=false)
    avionic_type_keys, manufacturer_keys, device_keys = RawPlaneObservation.stored_avionics_keys
    RawPlaneObservation.predict(RawPlaneObservation.get_model_data(avionic_type_keys, manufacturer_keys, device_keys, [self], include_appraisal)[0])
  end
  
  def self.predict(data)
    RawPlaneObservation.get_model.predict(data.collect{|obs| obs.collect(&:to_f)}).tolist()[0]
  end
end

# RawPlaneObservation.where(:raw_plane_id.in => RawPlane.where(price: 0).collect(&:id)).collect{|x| x.predict_price}