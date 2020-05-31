class NewAvionicsMatchRecord
  include Mongoid::Document
  field :given_name, type: String
  field :resolved_avionic, type: Array
  field :probability, type: Float
  
  def self.generate_cases
    RawPlane.all.shuffle.collect{|rp| rp.avionics_package||[]}.flatten.uniq.shuffle.each_slice(100) do |given_names|
      NewAvionicsMatchRecord.generate(given_names)
    end
  end

  def self.generate(given_names)
    existing_cases = NewAvionicsMatchRecord.where(:given_name.in => given_names).to_a
    new_cases = given_names-existing_cases.collect(&:given_name)
    if !new_cases.empty?
      results = JSON.parse(`python3 disambiguate_avionics.py '#{new_cases.to_json.gsub("'", "")}'`) rescue {}
      results.each do |given_name, result|
        namr = NewAvionicsMatchRecord.where(given_name: given_name).first_or_create
        namr.resolved_avionic = result["resolved_case"]
        namr.probability = result["output"][0]
        namr.save!
      end
    end
  end
end