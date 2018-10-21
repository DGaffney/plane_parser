class String
  def useless?
    self.useless_whitespace?
    
  end
  
  def useless_whitespace?
    self.gsub(/\W/, "").empty?
  end
end