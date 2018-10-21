class AvionicDisambiguator
  def self.avionics_manifest
    @@avionics_manifest ||= JSON.parse(File.read("avionic_mapping.json")).merge(self.common_pool_avionics_addendum)
  end

  def self.diverse_avionics_names
    @@diverse_avionics_names ||= Hash[JSON.parse(File.read("diverse_avionics_candidate_names.json"))]
  end

  def self.store_diverse_avionics_names
    precached_perms = {}
    self.avionics_manifest.each do |avionic_type, manufacturer_list|
      manufacturer_list.each do |manufacturer, devices|
        devices.each do |device|
          print(".")
          precached_perms[[avionic_type, manufacturer, device]] = self.diverse_perms(avionic_type, manufacturer, device)
        end
      end
    end;false
    f = File.open("diverse_avionics_candidate_names.json", "w")
    f.write(precached_perms.to_a.to_json)
    f.close
  end

  def self.diverse_perms(avionic_type, manufacturer, device)
    phrases = []
    1.upto(3).each do |count|
      [avionic_type, manufacturer, device].join(" ").split(" ").permutation(count).each do |phrase|
        phrases << phrase.join(" ").downcase
      end
    end
    diversity_scores = {}
    phrases.permutation(2).collect(&:sort).uniq.each do |first_str, second_str|
      score = self.quick_score(first_str, second_str)
      diversity_scores[first_str] = score if diversity_scores[first_str].nil? || diversity_scores[first_str] < score
      diversity_scores[second_str] = score if diversity_scores[second_str].nil? || diversity_scores[second_str] < score
    end;false
    cutoff = diversity_scores.values.percentile(0.25)
    diversity_scores.select{|k,v| v < cutoff}.keys
  end

  def self.all_perms(avionic_type, manufacturer, device)
    phrases = []
    min_scores = []
    1.upto(3).each do |count|
      [avionic_type, manufacturer, device].join(" ").split(" ").permutation(count).each do |phrase|
        phrases << phrase.join(" ").downcase
      end
    end
    phrases
  end

  def self.clean(string)
    string.strip.downcase.gsub(/[^a-z0-9]/i, ' ')
  end

  def self.quick_score(first_str, second_str)
    [
      JaroWinkler.jaro_distance(self.clean(first_str), self.clean(second_str)), 
      JaroWinkler.distance(self.clean(first_str), self.clean(second_str)), 
      String::Similarity.cosine(self.clean(first_str), self.clean(second_str))
    ].average
  end

  def self.disambiguation_candidates(avionic, limit=100)
    results = {}
    initial_scores = {}
    single_initial_scores = {}
    self.avionics_manifest.each do |avionic_type, manufacturer_list|
      manufacturer_list.each do |manufacturer, devices|
        devices.each do |device|
          single_initial_scores[[avionic_type, manufacturer, device]] = self.quick_score(avionic, self.diverse_avionics_names[[avionic_type, manufacturer, device]].join(" "))
        end
      end
    end;false
    single_initial_scores_threshold = single_initial_scores.values.percentile(0.95)
    single_initial_scores.select{|k,v| v > single_initial_scores_threshold}.keys.each do |avionic_type, manufacturer, device|
      initial_scores[[avionic_type, manufacturer, device]] = self.diverse_avionics_names[[avionic_type, manufacturer, device]].collect{|phrase| self.quick_score(avionic, phrase) }.max
    end;false
    high_score_threshold = initial_scores.values.percentile(0.90)
    initial_scores.select{|k,v| v >= high_score_threshold}.keys.each do |avionic_type, manufacturer, device|
      combo_scores = {}
      all_combos_to_test = self.all_combos(avionic_type, manufacturer, device);false
      all_combos_to_test.each do |combo|
        clean_combo = self.clean(combo)
        combo_scores[combo] = self.quick_score(avionic, combo)
      end;false
      combo_high_score_threshold = combo_scores.values.percentile(0.95)
      combo_scores.select{|k,v| v >= combo_high_score_threshold}.keys.each do |combo|
        row = self.generate_features(self.clean(avionic), self.clean(combo))
        next if row.empty?
        results[combo] = {data: row, avionic_type: avionic_type, manufacturer: manufacturer, device: device}
      end;false
    end;false
    results.sort_by{|k,v| self.quick_score(avionic, k)}.reverse.first(limit)
  end

  def self.generate_features(avionic, combo)
    cos_sim = String::Similarity.cosine(avionic, combo)
    lev_sim = String::Similarity.levenshtein(avionic, combo)
    lcs = Diff::LCS.LCS(avionic, combo)
    lcs_regex = Regexp.new(Regexp.quote(lcs.join("")))
    [
      [
        JaroWinkler.jaro_distance(avionic, combo), 
        JaroWinkler.distance(avionic, combo),
        cos_sim, 
        lev_sim,
        lcs.length,
        ((avionic_matched = avionic.match(lcs_regex)) && avionic_matched.to_s.length),
        ((combo_matched = combo.match(lcs_regex)) && combo_matched.to_s.length),
        avionic_matched.to_s.match(/\d/).to_s.length,
        combo_matched.to_s.match(/\d/).to_s.length,
      ], 
      self.string_features(avionic),
      self.string_features(combo),
      self.string_features((avionic.split("")&combo.split("")).join(""))
    ].flatten
  end
  
  def self.string_features(str)
    [
      str.length,
      str.length-str.gsub(/[[:punct:]]/, '').length,
      str.length-str.gsub(/\W/, "").length,
      str.length-str.gsub(/\d/, "").length,
      str.length-str.gsub(/[a-z]/, "").length,
      str.length-str.gsub(/[A-Z]/, "").length,
    ]
  end
  
  def self.avionic_substring_generator(term)
    [term, term.split(" ").collect(&:first).join(" "), term.split(" ").collect(&:first).join(""), term.split("").reject{|x| x.match(/[\d| ]/).nil?}.join(""), ""].reject{|x| x == " "}.collect(&:strip).uniq
  end

  def self.all_combos(avionic_type, manufacturer, device_name)
    combos = []
    self.avionic_substring_generator(avionic_type).each do |type|
      self.avionic_substring_generator(manufacturer).each do |man|
        self.avionic_substring_generator(device_name).each do |device|
          [type, man, device].permutation(3).each do |perm|
            combos << perm.join(" ")
          end
        end
      end
    end
    combos.uniq
  end

  def self.common_pool_avionics_addendum
    {"" => {"" => ["Rosen Sun Visors", "Electric Trim", "Factory Air Conditioning", "Flight Director", "Alternate Static Source", "Hobbs Meter", "Wingtip Strobes", "406 ELT", "Cirrus Airframe Parachute System ", "Air Conditioning", "Additional Equipment", "Polished Spinner", "RVSM", "Electric Pitch Trim", "Rudder Trim", "Wing Tip Strobes", "ELT", "Rosen Visors", "Heated Pitot", "Tinted Windows", "Vortex Generators", "Thrust Reversers", "Vertical Card Compass", "Auxiliary Stereo Input Jack", "Cleveland Wheels and Brakes", "Synthetic Vision Technology", "Dual Toe Brakes", "Garmin SafeTaxi", "Pitot Heat", "Intercom", "Enhanced Ground Proximity Warning System ", "Tow Bar", "Cleveland Wheels & Brakes", "Garmin 12\" LCD Displays", "Strobes", "EngineView Engine and Fuel Monitoring", "External Power Receptacle", "HSI", "GMU-44 Magnetometer", "XM Weather", "Emergency Locator Transmitter Remote Mounted Switch", "Wheel Pants", "Static System", "Freon Air Conditioning", "Fire Extinguisher", "Pitot System", "Static Wicks", "Radar Altimeter", "4 place intercom", "air condition", "2 place intercom", "6 place intercom", "one piece windshield", "vertical card compass", "true airspeed indicator", "cleveland brakes", "oxygen system", "flight director", "tip tanks", "ads b", "taws b", "nose baggage compartment", "tow bar", "landing light", "cargo door", "intercom", "electric trim", "inflatable door seal", "leather seats", "ground service plug", "shadin fuel flow", "gami injectors", "no known damage history", "elt", "oil quick drain", "hobbs meter", "long range tanks", "digital clock timer", "g meter", "active traffic", "music input", "electronic stability protection", "standby horizon", "bubble windows", "new battery", "standby vacuum", "dual vacuum pumps", "digital tachometer", "radar altimeter", "vortex generators", "cd player", "chartview", "synthetic vision", "glideslope", "attitude indicator", "lightweight starter", "insight engine monitor", "bogart cables", "wheel gear", "heated windshield", "bracket air filter", "wingtip mounted fiber optic nav light on indicators", "speed slope windshield", "annunciator panel", "fire extinguisher", "polished spinner", "altitude hold", "davtron clock", "dual controls", "smoke system", "fiki", "tinted windows", "precise flight pulselite system", "shoulder harnesses", "heat pitot", "nav com", "cowl flaps", "air oil separator", "brake de ice", "copilot instruments", "ack elt", "4 way baggage compartment system", "dual toe brakes", "digital chronometer", "wheel pants", "extended baggage", "stall warning", "flint tip tanks", "vertical rate selection", "altitude encoder", "altimeter", "engine heater", "terrain awareness warning system", "wheel fairings", "electric flaps", "slaved hsi", "honeywell mark viii egpws", "fuel flow", "de ice boots", "lead acid battery", "strikefinder", "control wheel steering", "abin cover", "aoa indicator", "oat gauge", "prop sync", "parking brake", "flap gap seals", "stol kit", "dual alternators", "transponder", "oil filter", "sierra quick release radome", "quartz chronometer", "digital oat", "dual engine driven vacuum pumps", "pilot toe brakes", "copilot toe brakes", "speed mods", "ptt", "dual flight control computers", "wingtip recognition lights", "backup battery", "refueling steps handles", "navigation lights", "alternate static source", "propeller synchrophaser", "radio master switch", "rosen articulating tinted sunvisors", "first aid kit", "exhaust gas temperature gauge", "gross weight increase", "artificial horizon", "surface illumination lights", "overhead switch panel", "turboplus intercooler", "nicad battery", "radar", "egt cht", "cursor control device", "marker beacon antenna", "hot prop", "windshield v brace", "ground power receptacle", "garmin safetaxi", "refreshment center", "control wheel clock", "right hand hinged window", "sky tec starter", "main battery concorde", "engine oil filter", "encoder equipped", "soundproof", "electric start", "alcohol props and windshield", "manifold tachometer vacuum sensors", "heated props", "horton stol", "dual marker beacons", "nav antenna", "dual yoke", "seat covers", "baggage door", "engine and fuel monitoring", "flight into known icing", "air data computer", "strobes", "altitude preselect", "hot plate", "yaw damper", "bleed air heat", "panel lights", "tow hook", "digital egt", "instrument panel", "push to talk", "perspective global connect", "audible stall warning system heated", "floor protectors", "rotating beacon", "robertson stol", "bubble canopy including sun protection", "american aviation intercoolers", "ground clearance switch", "digital fuel flow", "attitude", "dual altimeters", "complete logs", "known ice", "super features ", "garmin active traffic system", "electronic charts", "lightning protection system", "steam gauges", "flightcom digital clearance recorder", "power flow exhaust system", "pilot control wheel pitch trim switch ap disconnect", "rotor brake", "sun shields", "aux hydraulics", "original instrument panels", "3 blade", "dual honeywell air data computers", "usb power ports", "slick magnetos", "tail mounted rotating beacon", "dual transponders", "large non congealing oil cooler", "standby instruments", "oat probe", "bendix king weather radar", "float fittings", "external power receptacle", "new hoses", "electric boost pump", "stainless steel screw kit", "rvsm capable", "wing lockers", "float kit", "windshield hot plate", "custom air vents", "winglets"]}}
  end
end
#AvionicDisambiguator.disambiguation_candidates("Terra TDF100 ADF")
