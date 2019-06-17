class Tweeter
  def self.send_tweet_api(tweet_text)
    client = Twitter::REST::Client.new do |config|
      config.consumer_key        = SETTINGS["consumer_key"]
      config.consumer_secret     = SETTINGS["consumer_secret"]
      config.access_token        = SETTINGS["access_token"]
      config.access_token_secret = SETTINGS["access_secret"]
    end
    client.update(tweet_text)
  end

  def self.send_tweet_selenium(tweet_text)
    filename = (0...20).map { ('a'..'z').to_a[rand(26)] }.join
    f = File.open(plane.id.to_s+".json", "w")
    f.write({tweet: tweet_text, username: SETTINGS["twitter_user"], password: SETTINGS["twitter_password"]}.to_json)
    f.close
    puts "python scripts/tweet.py #{filename}.json"
    results = JSON.parse(`python scripts/tweet.py #{filename}.json`) rescue nil
    puts results
    `rm #{filename}.json`
    `pkill chrome`
    if !results.nil?
      plane.deal_tweeted = true
      plane.save!
    end
  end

  def self.run
    while true
      puts "Checking for tweets..."
      Tweet.check_for_tweets_to_send
      sleep(60*60)
    end
  end
end
