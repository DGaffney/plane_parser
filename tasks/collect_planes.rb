class CollectPlanes
  include Sidekiq::Worker
  sidekiq_options queue: :plane_collector

  def self.kickoff
    CollectPlanes.perform_async
  end

  def hostname
    "http://www.trade-a-plane.com"
  end

  def page_path
    "/search?s-type=aircraft&s-advanced=yes&sale_status=For+Sale&user_distance=1000000&s-sort_key=days_since_update&s-sort_order=asc&s-page_size=400"
  end

  def perform
    got_page = false
    while !got_page
      begin
      page_data = Nokogiri.parse(RestClient::Request.execute(:url => hostname+page_path, :method => :get, :verify_ssl => false));false
      got_page =  true
      rescue
        sleep(5)
        print(".")
        retry
      end
    end
    page_data.search(".result").map do |aircraft_listing|
      aircraft_link = aircraft_listing.search(".img_area a").collect{|l| l.attributes["href"].value}.first
      puts "\t"+aircraft_link
      got_page = false
      while !got_page
        begin
        aircraft = parse_aircraft(aircraft_listing, Nokogiri.parse(RestClient::Request.execute(:url => hostname+aircraft_link, :method => :get, :verify_ssl => false))).merge(link: aircraft_link, listing_id: listing_id(aircraft_link), category_level: category_level(aircraft_link))
        got_page =  true
        rescue
          sleep(5)
          print(".")
          retry
        end
      end
      next if aircraft[:make].nil?
      aircraft[:avionics_package].first.split(", ").collect(&:strip).reject{|x| x.downcase.include?("avionics")}.collect{|x| x.split("(")[0]}.reject{|x| x.nil? || x.empty?} if aircraft[:avionics_package].length == 1
      if RawPlane.where(listing_id: aircraft[:listing_id]).first.nil?
        rp = RawPlane.new(aircraft)
        #https://github.com/pastpages/archiveis
        rp.archived_link = `archiveis "#{aircraft_link}"`.strip
        rp.save!
        GenerateRawPlaneObservation.perform_async(rp.id)
        avionics = aircraft[:avionics_package]||[]
        NewAvionicsMatchRecord.generate(avionics)
      else
        plane = RawPlane.where(listing_id: aircraft[:listing_id]).first
        aircraft.each do |field, value|
          plane.send((field.to_s+"=").to_sym, value) if plane.send(field).nil? || plane.send(field) != value
        end
        plane.save!
      end
    end
    CheckRegistry.perform_in(60*60*3) if !Sidekiq::ScheduledSet.new.to_a.collect{|x| x.item["class"]}.include?("CheckRegistry")
    CollectPlanes.perform_in(60*60*3) if !Sidekiq::ScheduledSet.new.to_a.collect{|x| x.item["class"]}.include?("CollectPlanes")
  end

  def listing_id(aircraft_link)
    aircraft_link.split("&").select{|x| x.include?("listing_id=")}.first.split("=").last
  end

  def category_level(aircraft_link)
    aircraft_link.split("&").select{|x| x.include?("category_level1=")}.first.split("=").last
  end

  def parse_aircraft(aircraft_listing, aircraft_page)
    month, day, year = aircraft_listing.search("p.last-update").text.split(": ")[-1].split("/") rescue [nil,nil,nil]
    {
      created_at: Time.now,
      last_updated: (Time.parse("#{day}/#{month}/#{year}") rescue nil),
      region: (aircraft_listing.search("p.address span").select{|x| x["itemprop"] == "addressRegion"}.first.text rescue nil),
      locality: (aircraft_listing.search("p.address span").select{|x| x["itemprop"] == "addresslocality"}.first.text rescue nil),
      full_address: aircraft_listing.search("p.address").collect(&:text).join(" ").strip.gsub("  ", " "),
      price: aircraft_page.search("p.price span").text.to_f,
      make: (aircraft_page.search("li.makeModel span span").first.text.strip rescue nil),
      model: (aircraft_page.search("li.makeModel").first.text.gsub("Make/Model: ", "").gsub(aircraft_page.search(".makeModel span span").first.text, "").strip rescue nil),
      year: (aircraft_page.search("div#info-list-seller li")[1].text.gsub("Year: ", "").strip rescue nil),
      reg_number: (aircraft_page.search("div#info-list-seller li")[3].text.gsub("Registration #: ", "").strip rescue nil),
      serial_no: (aircraft_page.search("div#info-list-seller li")[4].text.gsub("Serial #: ", "").strip rescue nil),
      location: (aircraft_page.search("div#info-list-seller li")[5].text.gsub("Location: ", "").gsub(/\W/, " ").gsub(/\ +/, " ").strip rescue nil),
      avionics_package: aircraft_page.search("div#avionics_equipment pre").text.split(/[(\r\n)\n,.;]/).collect{|x| x.split(" - ")}.flatten.collect(&:strip).reject{|x| x.downcase.include?("avionics")}.collect{|x| x.split("(")[0]}.reject{|x| x.nil? || x.empty?},
      image_count: aircraft_page.search("div#photos li").count,
      header_image: aircraft_listing.search("img")[0].attributes["data-src"].value,
    }.merge(Hash[aircraft_page.search("div#general_specs p").collect{|x| k,v = x.text.gsub(" ", "_").downcase.split(":");[k.gsub("#", "num").to_sym, v]}]) 
  end
end
