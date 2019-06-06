class SaleChecker
  def check_reg_number_faa(raw_plane)
    page = Nokogiri.parse(RestClient.post("https://registry.faa.gov/aircraftinquiry/NNum_Results.aspx?NNumbertxt=#{raw_plane.reg_number}", {}))
    month, day, year = page.search("div span#content_lbCertDate").text.split("/")
    page.search("span#content_lbOwnerName")
    page.search("a#content_lbtnWarning")
    {
      make_model: (page.search("div span#content_lbMfrName").text.strip+" "+page.search("div span#content_Label7").text.strip rescue nil),
      last_certificate_date: (Time.parse([day, month, year].join("-")) rescue nil)
    }
  end
  
  def check_reg_number_flightaware(raw_plane)
    page = Nokogiri.parse(RestClient.get("https://flightaware.com/resources/registration/#{raw_plane.reg_number}"))
    year_make_model = page.search("div.medium-3")[0].children.first.text
    {
      make_model: (year_make_model.gsub(/^\d\d\d\d /, "") rescue nil),
      last_certificate_date: (Time.parse(page.search("tr.row1 td")[0].text) rescue nil)
    }
  end
  
  def check_reg_number(raw_plane)
    resp = check_reg_number_faa(raw_plane)
    resp = check_reg_number_flightaware(raw_plane) if resp.values.include?(nil)
    resp
  end

  def check_recently_sold(raw_plane)
    reg_result = check_reg_number(raw_plane)
    [reg_result, same_plane(raw_plane, reg_result)]
  end
  
  def same_plane(raw_plane, reg_result)
    String::Similarity.cosine("#{raw_plane.make} #{raw_plane.model}".strip, reg_result[:make_model].strip) > 0.3
  end
  
  def day_width_plane_cert(raw_plane, reg_results)
    (reg_results[:last_certificate_date] - raw_plane.last_updated)/60/60/24.0 rescue nil
  end

  def plane_changed_hands_after_post(raw_plane, reg_results)
    days_between_cert = day_width_plane_cert(raw_plane, reg_results)
    days_between_cert && days_between_cert > -30 && days_between_cert < 200
  end

  def planes_to_check
    fully_empty_cases = RawPlane.where(latest_certficate_reissue_date: nil).to_a.shuffle.collect(&:id)
    partially_empty_cases = RawPlane.where("latest_certficate_reissue_date.last_certificate_date": nil).to_a.shuffle.collect(&:id)-fully_empty_cases
    sales_previous_to_listing = RawPlane.where(:latest_certficate_reissue_date.ne => nil).select{|x| !x.latest_certficate_reissue_date["last_certificate_date"].nil? && (x.last_updated||x.id.generation_time) > x.latest_certficate_reissue_date["last_certificate_date"]}.collect(&:id)-(fully_empty_cases|partially_empty_cases)
    fully_empty_cases | partially_empty_cases | sales_previous_to_listing
  end

  def check_plane_registry(raw_plane_id)
    raw_plane = RawPlane.find(raw_plane_id)
    updates = (check_reg_number(raw_plane) rescue nil)
    return nil if updates.nil?
    raw_plane.latest_certficate_reissue_date = updates
    raw_plane.save!
  end
end