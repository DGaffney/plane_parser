class MarketDownload
  def self.download
    `wget http://registry.faa.gov/database/ReleasableAircraft.zip`
    `unzip ReleasableAircraft.zip`
  end

  def self.parse
    keys = `head -n1 MASTER.txt`.strip.split(",")
    first = true
    makes = File.read("ACFTREF.txt").split("\r\n").collect{|x| x.split(",")}.select{|x| x.length == 13};false
    hashed_makes = {}
    makes[1..-1].collect{|x| hashed_makes[x[0].strip] ||= Hash[makes.first.zip(x.collect(&:strip))]};false
    File.foreach("MASTER.txt") do |row|
      if row.strip.split(",").length == 34
        if !first
          parsed = Hash[keys.zip(row.strip.split(",").collect(&:strip))]
          match = hashed_makes[parsed["MFR MDL CODE"]]
          binding.pry
          if match
            cleaned = {
              make: match["MFR"],
              model: match["MODEL"],
              year: parsed["YEAR MFR"].to_f,
              last_cert_date: (Time.parse(parsed["CERT ISSUE DATE"]) rescue nil),
              last_action_date: (Time.parse(parsed["LAST ACTION DATE"]) rescue nil),
              certification: parsed["CERTIFICATION"],
              name: parsed["NAME"],
              street: parsed["STREET"],
              street2: parsed["STREET2"],
              city: parsed["CITY"],
              state: parsed["STATE"],
              zip_code: parsed["ZIP CODE"],
              region: parsed["REGION"],
              county: parsed["COUNTY"],
              country: parsed["COUNTRY"],
              mfr_mdl_code: parsed["MFR MDL CODE"],
              eng_mfr_mdl: parsed["ENG MFR MDL"],
              type_registrant: parsed["TYPE REGISTRANT"],
              type_aircraft: parsed["TYPE AIRCRAFT"],
              type_engine: parsed["TYPE ENGINE"],
              status_code: parsed["STATUS CODE"],
              mode_s_code: parsed["MODE S CODE"],
              fract_owner: parsed["FRACT OWNER"],
              air_worth_date: (Time.parse(parsed["AIR WORTH DATE"]) rescue nil),
              expiration_date: (Time.parse(parsed["EXPIRATION DATE"]) rescue nil),
              mode_s_code_hex: parsed["MODE S CODE HEX"],
              seats: match["NO-SEATS"].to_f,
              engines: match["NO-ENG"].to_f,
              speed: match["SPEED"].to_f,
              state: parsed["STATE"],
              unique_id: parsed["UNIQUE ID"],
              serial_number: parsed["SERIAL NUMBER"],
              n_number: parsed[keys.first],
            }
            if !cleaned[:last_action_date].nil?
              rr = RegistrationRecord.where(unique_id: cleaned[:unique_id], last_action_date: cleaned[:last_action_date]).first_or_create
              rr.content = cleaned
              rr.save!
          end
        else
          first = false
        end
      end
    end
  end

  def self.destroy
    `rm ReleasableAircraft.zip`
    `rm ardata.pdf`
    `rm ACFTREF.txt`
    `rm ENGINE.txt`
    `rm DEALER.txt`
    `rm MASTER.txt`
    `rm DOCINDEX.txt`
    `rm RESERVED.txt`
    `rm DEREG.txt`
  end

  def self.run
    self.download
    self.parse
    self.destroy
  end
end
