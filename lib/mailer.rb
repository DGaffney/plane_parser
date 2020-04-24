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