class Mailer
  def self.send_via_postmark(from, to, subject, content, content_html)
    to ||= "hello@cognitivesurpl.us"
    client = Postmark::ApiClient.new(SETTINGS["postmark_api_key"])
    client.deliver(
      from: from,
      to: to,
      subject: subject,
      html_body: content_html,
      track_opens: true
    )
  end
  
  def self.send_welcome_email(search_subscription)
    html = Mailer.welcome_email_content(search_subscription)
    text = Nokogiri.parse(html).text.strip
    Mailer.send_via_postmark("hello@cognitivesurpl.us", search_subscription.user_email, "Hello from TAP Deals!", text, html)
  end

  def self.welcome_email_content(search_subscription)
    @search_url = search_subscription.search_url
    @user_name = search_subscription.user_name
    @subscription_id = search_subscription.id
    ERB.new(File.read("./views/welcome_email.erb")).result(binding)
  end
end
# def get_leaderboard_email_content(ranks, businesses, business, personalization_text)
#   @ranks = Hash[ranks.collect{|id, ranks| [businesses[id], ranks]}.sort_by{|k,v| v[:rank]}];false
#   @email = self
#   @email_config = EmailConfig.find(self.email_config_id)
#   @business = business;false
#   @previous_ranks = BusinessRanking.where(email_config_id: self.email_config_id, :created_at.lte => Time.now-60*60*24*7).order(:created_at.desc).first.ranking_data rescue {};false
#   @business_ranks = @ranks.select{|k,v| k.id == @business.id}.values.first
#   @personalization_text = personalization_text||"Happy #{Time.now.strftime("%A")}! We've updated your leaderboard - amongst your competition, you're #{(@business_ranks[:rank].to_i+1).ordinalize}! Here's where #{@business.name} stacks up against all the competition as of late:"
#   @notification_count = Email.get_notification_ids(self.id).first.values.flatten.uniq.count
#   
# end
#
# class Mailer
#   attr_accessor :client
#   def initialize
#     self.client = Postmark::ApiClient.new('62426a3f-82f9-4fdd-850b-615449d9a1f5')
#     require 'postmark'
#
#     # Create an instance of Postmark::ApiClient:
#     client = Postmark::ApiClient.new('ceb77553-d5bb-4e7b-a060-67d60b8c0df0')
#
#     # Send an email:
#     client.deliver(
#       from: 'hello@cognitivesurpl.us',
#       to: 'hello@cognitivesurpl.us',
#       subject: 'Hello from Postmark',
#       html_body: '<strong>Hello</strong> dear Postmark user.',
#       track_opens: true)
#   end
# end
