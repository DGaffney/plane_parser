require 'distribution'
require 'postmark'
require 'stripe'
require 'pry'
require 'twitter'
require 'pycall/import'
include PyCall::Import
require 'sinatra'
require 'sidekiq'
require 'sidekiq/api'
require 'json'
require 'nokogiri'
#require 'selenium-webdriver'
require 'restclient'
require 'mongoid'
require 'string-similarity'
require 'dgaff'
require 'diff/lcs'
require 'jaro_winkler'
require 'linefit'
SETTINGS=JSON.parse(File.read("settings.json"))
Mongoid.load!("mongoid.yml", :development)
Stripe.api_key = SETTINGS["stripe_secret"]
$redis = Redis.new
Dir[File.dirname(__FILE__) + '/handlers/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/extensions/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/tasks/*.rb'].each {|file| require file }
# load all models.... because some weird interaction problem with sidekiq and pycall.
AvionicsMatchRecord.get_model
