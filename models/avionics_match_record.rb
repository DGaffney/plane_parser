class AvionicsMatchRecord
  pyimport :pickle
  pyfrom :sklearn, import: :datasets
  pyfrom :'sklearn.model_selection', import: :train_test_split
  pyfrom :'sklearn.ensemble', import: :GradientBoostingClassifier
  pyfrom :'sklearn.ensemble', import: :RandomForestClassifier
  include Mongoid::Document
  field :given_name, type: String
  field :nontrivial_candidates, type: Array
  field :candidate_vote_list, type: Hash
  field :current_ml_candidate_vote_list, type: Hash
  field :name_hit_count, type: Integer
  field :seen_count, type: Integer
  def sort_by_model(model=AvionicsMatchRecord.get_model)
    self.nontrivial_candidates.sort_by{|k,v| model.predict_proba([v["data"].collect(&:to_f)]).tolist()[0][1]}
  end

  def self.generate_cases
    RawPlane.all.shuffle.collect{|rp| rp.avionics_package||[]}.flatten.uniq.shuffle.each do |avionic|
      GenerateAvionicsMatchRecord.perform_async(avionic)
    end
  end
  
  def self.avionics_densities
    hit_counts = {}
    AvionicsMatchRecord.where(:candidate_vote_list.ne => []).each do |amr|
      amr.candidate_vote_list.each do |vote|
        hitval = amr.nontrivial_candidates[vote]
        hit_counts[hitval["avionic_type"]] ||= {count: 0, menu: {}}
        hit_counts[hitval["avionic_type"]][:count] += 1
        hit_counts[hitval["avionic_type"]][:menu][hitval["manufacturer"]] ||= {count: 0, menu: {}}
        hit_counts[hitval["avionic_type"]][:menu][hitval["manufacturer"]][:count] += 1
        hit_counts[hitval["avionic_type"]][:menu][hitval["manufacturer"]][:menu][hitval["device"]] ||= 0
        hit_counts[hitval["avionic_type"]][:menu][hitval["manufacturer"]][:menu][hitval["device"]] += 1
      end
    end
    hit_counts
  end

  def self.device_features(observation)
    manifest = AvionicDisambiguator.avionics_manifest
    [
      manifest.keys.index(observation["avionic_type"]),
      manifest[observation["avionic_type"]].keys.index(observation["manufacturer"]),
      manifest[observation["avionic_type"]][observation["manufacturer"]].index(observation["device"]),
    ]
  end

  def self.alter_features(observation, alter_observations)
    [
      alter_observations.select{|k,x| x["avionic_type"] == observation["avionic_type"]}.count/alter_observations.count.to_f,
      alter_observations.select{|k,x| x["avionic_type"] == observation["avionic_type"] && x["manufacturer"] == observation["manufacturer"]}.count/alter_observations.count.to_f,
      alter_observations.select{|k,x| x["avionic_type"] == observation["avionic_type"] && x["manufacturer"] == observation["manufacturer"] && x["device"] == observation["device"]}.count/alter_observations.count.to_f,
      alter_observations.select{|k,x| x["avionic_type"] == observation["avionic_type"] && x["device"] == observation["device"]}.count/alter_observations.count.to_f,
      alter_observations.count,
      alter_observations.reject{|k,x| x == observation}.collect{|k,x| x["data"].collect(&:to_f)}.transpose.collect(&:average)
    ]
  end
  
  def self.get_row(observation, alter_observations)
    [
      self.alter_features(observation, alter_observations),
      self.device_features(observation), 
      observation["data"]
    ].flatten.collect(&:to_f)
  end

  def self.get_model_data(query=AvionicsMatchRecord.where(:candidate_vote_list.ne => {}), include_ml_candidates=false)
    dataset = []
    labels = []
    candidates_to_use = include_ml_candidates ? [:candidate_vote_list, :current_ml_candidate_vote_list] : [:candidate_vote_list]
    query.each do |amr|
      candidates_to_use.each do |candidate_type|
        (amr.send(candidate_type)||{}).each do |vote_index, vote_data|
          dataset << self.get_row(amr.nontrivial_candidates[vote_index.to_i][1], amr.nontrivial_candidates)
          labels << 1
          random_obs = amr.nontrivial_candidates.reject{|k,v| amr.nontrivial_candidates[vote_index.to_i][1]["data"] == v["data"]}.collect(&:last).shuffle.first rescue nil
          if random_obs
            dataset << self.get_row(random_obs, amr.nontrivial_candidates)
            labels << 0
          end
          amr.nontrivial_candidates.select{|c| c[1]["manufacturer"] == vote_data["manufacturer"] && c[1]["device"] == vote_data["device"] && c[1]["avionic_type"] == vote_data["avionic_type"]}.each do |alter_name, alter_data|
            dataset << self.get_row(alter_data, amr.nontrivial_candidates)
            labels << 1
            random_obs = amr.nontrivial_candidates.reject{|k,v| v["data"] == alter_data["data"] || amr.nontrivial_candidates[vote_index.to_i][1]["data"] == v["data"]}.collect(&:last).shuffle.first rescue nil
            if random_obs
              dataset << self.get_row(random_obs, amr.nontrivial_candidates)
              labels << 0
            end
          end
        end
      end
    end;false
    return dataset, labels
  end

  def likeliest_choice
    predictions = AvionicsMatchRecord.predict(self.nontrivial_candidates.collect{|l,c| AvionicsMatchRecord.get_row(c, self.nontrivial_candidates)})
    return self.nontrivial_candidates.to_a[predictions.index(predictions.max)], predictions.max
  end

  def self.train_model(query=AvionicsMatchRecord.where(:candidate_vote_list.ne => {}), include_ml_candidates=false)
    x, y = self.get_model_data(query, include_ml_candidates)
    x_train, x_test, y_train, y_test  = train_test_split(x,y, test_size: 0.2, random_state: Time.now.to_i)
    model = RandomForestClassifier.new(n_estimators=50)
    model = GradientBoostingClassifier.new()
    model.fit(x_train, y_train)
    puts model.score(x_test, y_test)
    model.fit(x, y)
    binding.pry
    pickled = pickle.dumps(model);false
    f = File.open("avionics_matcher.pkl", "w")
    f.write(pickled)
    f.close
    return model
  end

  def self.get_model
    @@current_avionics_model ||= pickle.loads(open("avionics_matcher.pkl").read)
  end

  def shortlist
    model = AvionicsMatchRecord.get_model
    Hash[self.nontrivial_candidates.collect{|k,v| [k,{score: model.predict_proba([v["data"].collect(&:to_f)]).tolist()[0][1], index: self.nontrivial_candidates.keys.index(k)}]}.sort_by{|k,v| v[:score]}.reverse.first(20)]
  end

  def self.set_shortlist
    model = AvionicsMatchRecord.get_model
    AvionicsMatchRecord.all.each do |amr|
      amr.ml_shortlist = Hash[amr.nontrivial_candidates.collect{|k,v| [k,{score: model.predict_proba([v["data"].collect(&:to_f)]).tolist()[0][1], index: amr.nontrivial_candidates.keys.index(k)}]}.sort_by{|k,v| v[:score]}.reverse.first(20)]
      amr.save!
      print(".")
    end
  end
  
  def self.predict(data, model=AvionicsMatchRecord.get_model)
    model.predict_proba(data.collect{|r| r.collect(&:to_f)}).tolist().collect{|x| x[1]}
  end

  def voted_cases
    self.candidate_vote_list.collect{|v| self.nontrivial_candidates.select{|k,r| k == v}}.first
  end
  
  def self.resolved_observations
    outdata = []
    self.all.each do |amr|
      (amr.voted_cases||[]).each do |voted_case|
        outdata << voted_case
      end
    end
    outdata
  end
  
  def self.propagate_labels(propagation_threshold=0.95)
    dataset, labels = self.get_model_data(AvionicsMatchRecord.and({:candidate_vote_list.ne => {}}, {:current_ml_candidate_vote_list.ne => {}}), true)
    predictions = self.predict(dataset)
    min_cut = nil
    1.upto(100).each do |cutoff|
      if labels.zip(predictions).select{|x| x[1] >= cutoff/100.0}.collect(&:first).average > propagation_threshold
        min_cut = cutoff
        break
      end
    end
    return nil if min_cut.nil?
    c = 0
    AvionicsMatchRecord.all.each do |amr|
      choice, pred = amr.likeliest_choice
      if pred > min_cut/100.0
        binding.pry
        index = amr.nontrivial_candidates.index(amr.nontrivial_candidates.select{|x| x[0] == choice[0]}.first)
        candidate = amr.nontrivial_candidates[index][1]
        amr.current_ml_candidate_vote_list ||= {}
        amr.current_ml_candidate_vote_list[index] ||= {avionic_type: candidate["avionic_type"], manufacturer: candidate["manufacturer"], device: candidate["device"], count: 0}
        amr.current_ml_candidate_vote_list[index][:count] += 1
        amr.save!
        c += 1
      end
    end
    puts "Propagated #{c} labels at min pred score of #{min_cut/100.0}"
  end
end