load 'environment.rb'
task :collector do
  while true
    CollectPlanes.kickoff
    sleep(60*60*6)
  end
end
task :delister do
  while true
    begin
      RawPlane.where(:delisted.in => [false, nil]).collect{|x| print(".");x.delisted = !x.plane_online?;x.save!;sleep(10)}
    rescue
      retry
    end
  end
end
task :tweeter do
  Tweeter.run
end
task :check_subscriptions do
  SubscriptionChecker.check_subscriptions
end
task :market_download do
  MarketDownload.run
end