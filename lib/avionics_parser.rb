class AvionicParser
  def hostname
    "http://naaa.trade-a-plane.com"
  end

  def go_back(driver)
    t = Time.now
    wait = Selenium::WebDriver::Wait.new(timeout: 60)
    body = driver.find_element(:css, "body")
    driver.execute_script("window.history.go(-1)")
    wait.until {driver.find_element(:css, "body") != body}    
    tt = Time.now
    puts "Took #{tt-t} seconds to go back a page."
  end

  def get_manufacturer_data(driver)
    manufacturer_hash = {}
    1.upto(Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "manufacturer")[0]).options[1..-1].count) do |option_index|
      manufacturer_option = Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "manufacturer")[0]).options[option_index]
      manufacturer_text = manufacturer_option.text
      puts "Getting Manufacturer of #{manufacturer_text}..."
      puts "\tOption index is #{option_index}"
      manufacturer_option.click
      driver.find_elements(tag_name: "button")[-1].click
      manufacturer_hash[manufacturer_text] ||= get_model_data(driver)
      go_back(driver)
    end
    go_back(driver)
    manufacturer_hash
  end

  def get_avionic_data(driver)
    avionic_mapping = {}
    puts "Getting Avionics..."
    driver.navigate.to hostname+"/valuation-avionics/choose-type?class=btn"
    1.upto(Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "avionic_type")[0]).options[1..-1].count) do |option_index|
      avionic_option = Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "avionic_type")[0]).options[option_index]
      avionic_text = avionic_option.text
      next if avionic_mapping[avionic_text]
      puts "Getting avionic of #{avionic_text}..."
      puts "Option index is #{option_index}"
      avionic_option.click
      driver.find_elements(tag_name: "button")[-1].click
      avionic_mapping[avionic_text] = get_manufacturer_data(driver)
    end
    go_back(driver)
    avionic_mapping
  end

  def get_model_data(driver)
    Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "model")[0]).options.collect(&:text)[1..-1]
  end
  
  def run
    Nokogiri.parse(RestClient.get(hostname+"/valuation-avionics/choose-type?class=btn")).search("select")[1].children[1..-1].each do |avionics_type|
      options = Selenium::WebDriver::Firefox::Options.new
      options.binary = "geckodriver" 
      driver = Selenium::WebDriver.for :firefox
      driver.navigate.to hostname+"/valuation-avionics/choose-type?class=btn"
      avionic_mapping = get_avionic_data(driver)
      f = File.open("avionic_mapping.json", "w")
      f.write(avionic_mapping.to_json)
      f.close
    end
    
  end
end