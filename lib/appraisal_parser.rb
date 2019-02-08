require 'selenium-webdriver'
class AppraisalParser
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

  def get_manufacturer_data(driver, appraisal_text, year_text)
    manufacturer_hash = {}
    1.upto(Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "ac_mfr")[0]).options[1..-1].count) do |option_index|
      manufacturer_option = Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "ac_mfr")[0]).options[option_index]
      manufacturer_text = manufacturer_option.text
      puts "Getting Manufacturer of #{manufacturer_text}..."
      puts "\tOption index is #{option_index}"
      manufacturer_option.click
      driver.find_elements(tag_name: "button")[-1].click
      get_model_data(driver, appraisal_text, year_text, manufacturer_text)
      #manufacturer_hash[manufacturer_text] ||= 
      go_back(driver)
    end
    go_back(driver)
    manufacturer_hash
  end

  def get_year_data(driver, appraisal_text)
    year_hash = {}
    1.upto(Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "ac_year")[0]).options[1..-1].count) do |option_index|
      year_option = Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "ac_year")[0]).options[option_index]
      year_text = year_option.text
      puts "Getting Year of #{year_text}..."
      puts "\tOption index is #{option_index}"
      year_option.click
      driver.find_elements(tag_name: "button")[-1].click
      get_manufacturer_data(driver, appraisal_text, year_text)
      #year_hash[year_text] ||= 
      go_back(driver)
    end
    go_back(driver)
    year_hash
  end

  def get_all_appraisal_data(driver)
    finished_trees ||= []
    while true
      begin
        driver.navigate.to hostname+"/valuations/choose-type"
        1.upto(Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "ac_type")[0]).options[1..-1].count) do |ac_type_index|
          next if finished_trees.include?([ac_type_index, nil, nil, nil])
          appraisal_option = Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "ac_type")[0]).options[ac_type_index]
          appraisal_text = appraisal_option.text
          puts "Getting appraisals for #{appraisal_text}..."
          puts "Option index is #{ac_type_index}"
          appraisal_option.click
          driver.find_elements(tag_name: "button")[-1].click
          1.upto(Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "ac_year")[0]).options[1..-1].count) do |ac_year_index|
            next if finished_trees.include?([ac_type_index, ac_year_index, nil, nil])
            year_option = Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "ac_year")[0]).options[ac_year_index]
            year_text = year_option.text
            puts "Getting Year of #{year_text}..."
            puts "\tOption index is #{ac_year_index}"
            year_option.click
            driver.find_elements(tag_name: "button")[-1].click
            1.upto(Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "ac_mfr")[0]).options[1..-1].count) do |ac_mfr_index|
              next if finished_trees.include?([ac_type_index, ac_year_index, ac_mfr_index, nil])
              manufacturer_option = Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "ac_mfr")[0]).options[ac_mfr_index]
              manufacturer_text = manufacturer_option.text
              puts "Getting Manufacturer of #{manufacturer_text}..."
              puts "\tOption index is #{ac_mfr_index}"
              manufacturer_option.click
              driver.find_elements(tag_name: "button")[-1].click
              if !driver.find_elements(name: "ac_model").empty?
                1.upto(Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "ac_model")[0]).options[1..-1].count) do |ac_model_type|
                  next if finished_trees.include?([ac_type_index, ac_year_index, ac_mfr_index, ac_model_type])
                  model_option = Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "ac_model")[0]).options[ac_model_type]
                  model_text = model_option.text
                  puts "Getting Model of #{model_text}..."
                  puts "\tOption index is #{ac_model_type}"
                  model_option.click
                  driver.find_elements(tag_name: "button")[-1].click
                  $appraisal_mapping[appraisal_text] ||= {}
                  $appraisal_mapping[appraisal_text][year_text] ||= {}
                  $appraisal_mapping[appraisal_text][year_text][manufacturer_text] ||= {}
                  $appraisal_mapping[appraisal_text][year_text][manufacturer_text][model_text] = driver.find_elements(class: "valuation-value").collect(&:text).collect{|x| x.gsub("$", "").gsub(",", "").to_f}
                  go_back(driver)
                  finished_trees << [ac_type_index, ac_year_index, ac_mfr_index, ac_model_type]
                end
              end
              go_back(driver)
              finished_trees << [ac_type_index, ac_year_index, ac_mfr_index, nil]
            end
            go_back(driver)
            finished_trees << [ac_type_index, ac_year_index, nil, nil]
          end
          finished_trees << [ac_type_index, nil, nil, nil]
        end
      rescue
        retry
      end
    end
  end
  def get_appraisal_data(driver)
    $appraisal_mapping ||= {}
    puts "Getting Avionics..."
    driver.navigate.to hostname+"/valuations/choose-type"
    1.upto(Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "ac_type")[0]).options[1..-1].count) do |option_index|
      appraisal_option = Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "ac_type")[0]).options[option_index]
      appraisal_text = appraisal_option.text
      puts "Getting appraisals for #{appraisal_text}..."
      puts "Option index is #{option_index}"
      appraisal_option.click
      driver.find_elements(tag_name: "button")[-1].click
      get_year_data(driver, appraisal_text)
      #appraisal_mapping[appraisal_text]
    end
    go_back(driver)
    $appraisal_mapping
  end

  def get_model_data(driver, appraisal_text, year_text, manufacturer_text)
    if !driver.find_elements(name: "ac_model").empty?
      1.upto(Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "ac_model")[0]).options[1..-1].count) do |option_index|
        model_option = Selenium::WebDriver::Support::Select.new(driver.find_elements(name: "ac_model")[0]).options[option_index]
        model_text = model_option.text
        puts "Getting Model of #{model_text}..."
        puts "\tOption index is #{option_index}"
        model_option.click
        driver.find_elements(tag_name: "button")[-1].click
        $appraisal_mapping[appraisal_text] ||= {}
        $appraisal_mapping[appraisal_text][year_text] ||= {}
        $appraisal_mapping[appraisal_text][year_text][manufacturer_text] ||= {}
        $appraisal_mapping[appraisal_text][year_text][manufacturer_text][model_text] = driver.find_elements(class: "valuation-value").collect(&:text).collect{|x| x.gsub("$", "").gsub(",", "").to_f}
        #model_hash[model_text] ||= 
        go_back(driver)
      end
    end
  end

  def run
    appraisal_mapping = {}
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--ignore-certificate-errors')
    options.add_argument('--disable-popup-blocking')
    options.add_argument('--disable-translate')
    driver = Selenium::WebDriver.for :chrome, options: options
    driver.navigate.to hostname+"/valuations/choose-type"
    get_appraisal_data(driver)
    Nokogiri.parse(RestClient.get(hostname+"/valuations/choose-type")).search("select")[1].children[1..-1].each do |vehicle_type|
      appraisal_mapping[vehicle_type] = 
      # f = File.open("avionic_mapping.json", "w")
      # f.write(avionic_mapping.to_json)
      # f.close
    end
    
  end
end