require 'sinatra'
require 'rack'
load 'environment.rb'
set :root, File.dirname(__FILE__)
set :environment, :development
set :run, false
configure do
  set :erb, :layout => :'views/layouts'
end
run Site