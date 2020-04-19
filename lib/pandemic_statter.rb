class PandemicStatter
  def self.num_of_seats_map
    if @num_of_seats.nil?
      @num_of_seats = {}
      RawPlane.where(:num_of_seats.ne => nil).each{|x| 
        @num_of_seats[x.make] ||= {}
        @num_of_seats[x.make][x.model] ||= {seats: x.num_of_seats, count: 0}
        @num_of_seats[x.make][x.model][:count] += 1
      }
      @num_of_seats
    else
      @num_of_seats
    end
  end

  def self.num_of_seats(plane)
    if !plane.num_of_seats.nil?
      seats = plane.num_of_seats
    elsif !self.num_of_seats_map[plane.make].nil? && !self.num_of_seats_map[plane.make][plane.model].nil?
      seats = self.num_of_seats_map[plane.make][plane.model][:seats]
    elsif !self.num_of_seats_map[plane.make].nil? && self.num_of_seats_map[plane.make][plane.model].nil?
      num = self.num_of_seats_map[plane.make].collect{|k,v| v[:seats]*v[:count]*String::Similarity.cosine(plane.model, k)}.sum
      denom = self.num_of_seats_map[plane.make].collect{|k,v| v[:count]*String::Similarity.cosine(plane.model, k)}.sum
      seats = num/denom
    else
      seats = nil
    end
    seats = nil if seats.to_f.nan?
    seats
  end

  def self.start_date
    Time.parse("February 21 2020")
  end

  def self.end_date
    Time.parse("March 15 2020")
  end
  def self.diff_row(plane, other_plane, pandemic)
    {
      diff: other_plane.price-plane.price,
      width: (plane.created_at-other_plane.created_at)/60/60/24.0,
      old: other_plane.price,
      new: plane.price,
      reg_number: plane.reg_number,
      year: plane.year.to_i,
      make: plane.make,
      tt: plane.total_time,
      model: plane.model,
      price: plane.price,
      category: plane.category_level,
      flight_rules: plane.flight_rules,
      num_of_seats: (self.num_of_seats(plane)||self.num_of_seats(other_plane)).to_f,
      condition: plane.condition,
      image_count: plane.image_count,
      quarter: (plane.created_at.strftime("%m").to_f/3).ceil,
      avionics_count: (plane.avionics_package.count.to_f+other_plane.avionics_package.count.to_f)/2.0,
      pandemic: pandemic,
    }
  end

  def self.plane_row(plane, pandemic)
    {
      price: plane.price,
      reg_number: plane.reg_number,
      year: plane.year.to_i,
      make: plane.make,
      tt: plane.total_time,
      model: plane.model,
      category: plane.category_level,
      flight_rules: plane.flight_rules,
      num_of_seats: self.num_of_seats(plane).to_f,
      condition: plane.condition,
      image_count: plane.image_count,
      quarter: (plane.created_at.strftime("%m").to_f/3).ceil,
      avionics_count: plane.avionics_package.count.to_f,
      pandemic: pandemic,
    }
  end

  def self.generate_diff_observations
    diffs = []
    cases = []
    planes = RawPlane.where(:price.nin => [nil, 0], :price.lt => 300000, :created_at.gte => end_date, :reg_number.nin => ["Not Listed", "", nil])
    planes.each do |plane|
      cases << plane.id
      RawPlane.where(reg_number: plane.reg_number, :price.lt => 300000, :id.ne => plane.id, :created_at.gte => end_date-60*60*24*180).each do |other_plane|
        diffs << self.diff_row(plane, other_plane, 1)
        cases << other_plane.id
      end
    end
    prev_time = start_date-(60*60*24*180 + 60*60*24*rand(200))
    planes = RawPlane.where(:price.nin => [nil, 0], :price.lt => 300000, :created_at.gte => prev_time, :created_at.lte => start_date, :reg_number.nin => ["Not Listed", "", nil], :id.nin => cases)
    planes.each do |plane|
      RawPlane.where(reg_number: plane.reg_number, :price.lt => 300000, :id.ne => plane.id, :created_at.gte => prev_time-60*60*24*180).each do |other_plane|
      diffs << self.diff_row(plane, other_plane, 0)
      end
    end
    diffs
  end

  def self.generate_observations
    obs = []
    cases = []
    planes = RawPlane.where(:price.nin => [nil, 0], :price.lt => 300000, :created_at.gte => end_date, :reg_number.nin => ["Not Listed", "", nil])
    planes.each do |plane|
      cases << plane.id
      obs << self.plane_row(plane, 1)
    end
    prev_time = Time.now-(60*60*24*180 + 60*60*24*rand(200))
    planes = RawPlane.where(:price.nin => [nil, 0], :price.lt => 300000, :created_at.gte => prev_time, :created_at.lte => start_date, :reg_number.nin => ["Not Listed", "", nil], :id.nin => cases)
    planes.each do |plane|
      obs << self.plane_row(plane, 0)
    end
    obs
  end
  
  def self.convert_to_regression_data(obs, categorical_fields=[:make, :category, :condition, :flight_rules])
    reg_obs = []
    cat_transformations = {}
    categorical_fields.each do |cat_field|
      valids = obs.collect{|x| x[cat_field]}.counts.sort_by{|k,v| v}.reverse.first(5).collect(&:first)
      cat_transformations[cat_field] = valids
    end
    obs.each do |row|
      reg_row = Hash[row.reject{|k,v| categorical_fields.include?(k)}.collect{|k,v| [k.to_s, v]}]
      categorical_fields.each do |field|
        cat_transformations[field].each do |dummy|
          dummy_name = "#{field}_#{dummy||"none"}".downcase.gsub("+", "").gsub("/", "")
          if row[field] == dummy
            reg_row[dummy_name] = 1
          else
            reg_row[dummy_name] = 0
          end
        end
      end
      reg_obs << reg_row
    end
    reg_obs
  end
  
  def self.store_as_csv(reg_obs, filename)
    keys = reg_obs.collect(&:keys).flatten.uniq
    csv = CSV.open(filename, "w")
    csv << keys
    reg_obs.each do |row|
      csv << keys.collect{|k| row[k]}
    end
    csv.close
    [keys, filename]
  end
  
  def self.print_stata_commands(keys, filename)
    ip = `ifconfig`.split("\n").select{|x| x.include?("inet ") && !x.include?("127.0.0.1")}.first.split(":")[1].split(" ")[0]
    puts "Download:"
    puts "rsync root@#{ip}:plane_parser/#{filename} #{filename}\n"
    puts "Regression:"
    if keys.include?("diff")
      puts "clear"
      puts "inshseet using ~/#{filename}"
      puts "regress diff #{(keys-["diff", "old", "new", "price", "reg_number", "model"]).join(" ")}\n"
    else
      puts "clear"
      puts "inshseet using ~/#{filename}"
      puts "regress price #{(keys-["price", "diff", "reg_number", "model"]).join(" ")}\n"
    end
  end

  def self.run
    self.print_stata_commands(
      *self.store_as_csv(
        self.convert_to_regression_data(
          self.generate_diff_observations
        ),
        "pandemic_effect_diff.csv"
      )
    )
    self.print_stata_commands(
      *self.store_as_csv(
        self.convert_to_regression_data(
          self.generate_observations
        ),
        "pandemic_effect.csv"
      )
    )
  end
end
