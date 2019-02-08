class Appraiser
  def self.appraisals
    if @appraisals
      @appraisals
    else
      @appraisals ||= JSON.parse(File.read("appraisals.json"))
      @appraisals["Homebuilt Airplane"].each do |year, makes|
        makes.each do |make, models|
          models.each do |model, prices|
            @appraisals["Airplanes"] ||= {}
            @appraisals["Airplanes"][year] ||= {}
            @appraisals["Airplanes"][year][make] ||= {}
            @appraisals["Airplanes"][year][make][model] ||= prices
          end
        end
      end
      @appraisals["Factory Airplane"].each do |year, makes|
        makes.each do |make, models|
          models.each do |model, prices|
            @appraisals["Airplanes"] ||= {}
            @appraisals["Airplanes"][year] ||= {}
            @appraisals["Airplanes"][year][make] ||= {}
            @appraisals["Airplanes"][year][make][model] ||= prices
          end
        end
      end
      @appraisals
    end
  end

  def self.likely_appraisal_for_imputed_record(imputed_record)
    search_years = (imputed_record["year"].to_i-3).upto((imputed_record["year"].to_i+3)).to_a
    if imputed_record["category_level"].include?("Helicopters")
      type_key = "Helicopter"
    else
      type_key = "Airplanes"
    end
    search_space = self.appraisals[type_key].select{|k,v| search_years.include?(k.to_i)}
    potential_makes = search_space.values.collect(&:keys).flatten.uniq
    likeliest_makes = potential_makes.collect{|m| [m, AvionicDisambiguator.quick_score(m, imputed_record["make"])]}.sort_by{|k,v| v}.reverse.first(10).collect(&:first)
    likeliest_years = search_space.keys.collect{|k| [k, (k.to_i-imputed_record["year"]).abs]}.sort_by{|k,v| v}.first(10).collect(&:first)
    likeliest_models = search_space.values.collect(&:values).flatten.collect(&:keys).flatten.uniq.collect{|m| [m, AvionicDisambiguator.quick_score(m, imputed_record["model"])]}.sort_by{|k, v| v}.reverse.first(10).collect(&:first)
    step_order = 0.upto(9).to_a.repeated_permutation(3).sort_by{|k| k.sum*k.max}
    found_price = nil
    last_iter = []
    step_order.each do |make_i, year_i, model_i|
      found_price = self.appraisals[type_key][likeliest_years[year_i]][likeliest_makes[make_i]][likeliest_models[model_i]] rescue nil
      last_iter  = [make_i, year_i, model_i]
      break if found_price
    end
    
    return [likeliest_years[last_iter[0]], likeliest_makes[last_iter[1]], likeliest_models[last_iter[2]]], found_price
  end
end
