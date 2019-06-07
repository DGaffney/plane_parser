class CollectPlanes
  include Sidekiq::Worker
  sidekiq_options queue: :plane_collector
  def self.kickoff
    1.upto(300) do |page|
      CollectPlanes.perform_async(page)
    end
  end
  def hostname
    "http://www.trade-a-plane.com"
  end

  def page_path(page=1)
    "/search?s-type=aircraft&s-sort_key=days_since_update&s-sort_order=asc&s-page=#{page}&s-page_size=10"
  end

  def perform(page)
    puts page
    page_data = Nokogiri.parse(RestClient::Request.execute(:url => hostname+page_path(page), :method => :get, :verify_ssl => false));false
    page_data.search(".result").map do |aircraft_listing|
      aircraft_link = aircraft_listing.search(".img_area a").collect{|l| l.attributes["href"].value}.first
      puts "\t"+aircraft_link
      aircraft = parse_aircraft(aircraft_listing, Nokogiri.parse(RestClient::Request.execute(:url => hostname+aircraft_link, :method => :get, :verify_ssl => false))).merge(link: aircraft_link, listing_id: listing_id(aircraft_link), category_level: category_level(aircraft_link))
      aircraft[:avionics_package].first.split(", ").collect(&:strip).reject{|x| x.downcase.include?("avionics")}.collect{|x| x.split("(")[0]}.reject{|x| x.nil? || x.empty?} if aircraft[:avionics_package].length == 1
      if RawPlane.where(listing_id: aircraft[:listing_id]).first.nil?
        rp = RawPlane.new(aircraft)
        #https://github.com/pastpages/archiveis
        rp.archived_link = `archiveis "#{aircraft_link}"`.strip
        rp.save!
        r
        GenerateRawPlaneObservation.perform_async(rp.id)
        (aircraft[:avionics_package]||[]).each do |avionic|
          GenerateAvionicsMatchRecord.perform_async(avionic)
        end
      else
        plane = RawPlane.where(listing_id: aircraft[:listing_id]).first
        aircraft.each do |field, value|
          plane.send((field.to_s+"=").to_sym, value) if plane.send(field).nil?
        end
        plane.save!
      end
    end
    sleep(10)
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
      last_updated: (Time.parse("#{day}/#{month}/#{year}") rescue nil),
      region: (aircraft_listing.search("p.address span").select{|x| x["itemprop"] == "addressRegion"}.first.text rescue nil),
      locality: (aircraft_listing.search("p.address span").select{|x| x["itemprop"] == "addresslocality"}.first.text rescue nil),
      full_address: aircraft_listing.search("p.address").collect(&:text).join(" ").strip.gsub("  ", " "),
      price: aircraft_page.search("p.price span").text.to_f,
      make: aircraft_page.search("li.makeModel span span").text.strip,
      model: aircraft_page.search("li.makeModel").text.gsub("Make/Model: ", "").gsub(aircraft_page.search(".makeModel span span").text, "").strip,
      year: aircraft_page.search("div#main_info li")[1].text.gsub("Year: ", "").strip,
      reg_number: aircraft_page.search("div#main_info li")[3].text.gsub("Registration #: ", "").strip,
      serial_no: aircraft_page.search("div#main_info li")[4].text.gsub("Serial #: ", "").strip,
      location: aircraft_page.search("div#main_info li")[5].text.gsub("Location: ", "").gsub(/\W/, " ").gsub(/\ +/, " ").strip,
      avionics_package: aircraft_page.search("div#avionics_equipment pre").text.split(/[(\r\n)\n,.;]/).collect{|x| x.split(" - ")}.flatten.collect(&:strip).reject{|x| x.downcase.include?("avionics")}.collect{|x| x.split("(")[0]}.reject{|x| x.nil? || x.empty?},
      image_count: aircraft_page.search("div#photos li").count,
    }.merge(Hash[aircraft_page.search("div#general_specs p").collect{|x| k,v = x.text.gsub(" ", "_").downcase.split(":");[k.gsub("#", "num").to_sym, v]}]) 
  end
end
