class SendTweet
  include Sidekiq::Worker
  def perform(tweet_id)
    tweet = Tweet.find(tweet_id)
    if Time.now > tweet.send_tweet_at
      tweet.send_tweet
    else
      SendTweet.perform_at(tweet.send_tweet_at, tweet.id)
    end
  end
end