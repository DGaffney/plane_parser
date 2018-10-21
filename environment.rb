require 'pry'
require 'pycall/import'
include PyCall::Import
require 'sinatra'
require 'sidekiq'
require 'json'
require 'nokogiri'
#require 'selenium-webdriver'
require 'restclient'
require 'mongoid'
require 'string-similarity'
require 'dgaff'
require 'diff/lcs'
require 'jaro_winkler'
Mongoid.load!("mongoid.yml", :development)
$redis = Redis.new
Dir[File.dirname(__FILE__) + '/handlers/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/extensions/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/tasks/*.rb'].each {|file| require file }
# load all models.... because some weird interaction problem with sidekiq and pycall.
AvionicsMatchRecord.get_model