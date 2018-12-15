task :collector do
  while true
    CollectPlanes.kickoff
    sleep(60*60*6)
  end
end
task :delister do
  while true
    begin
      RawPlane.where(delisted: nil).collect{|x| print(".");x.delisted = !x.plane_online?;x.save!;}
    rescue
      retry
    end
  end
end

