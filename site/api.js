var config = require('../settings.json');
var qs = require('querystring')
const request = require('request');
const requestprom = require('request-promise')

function get(path, callback) {
  request({
    url: "http://"+config.api_host+":9292/"+path,
    json: true
  }, function (error, response, body) {
    if (error || response.statusCode !== 200) {
      return callback(error || {statusCode: response.statusCode});
    }
    callback(null, body);  
  });
}

function post(path, data, callback){
    options = {
      method: 'POST',
      uri: "http://"+config.api_host+":9292/"+path,
      body: data,
      json: true 
        // JSON stringifies the body automatically
    }
  requestprom(options)
    .then(function (response) {
      callback(null, response);
    })
    .catch(function (error) {
      console.error(error)
    })
}

module.exports = {
  settings: config,
  ping: function (callback) {
      get("ping.json", function(err, body){
          return callback(body)
      })
  },
  parse_search_page: function (search_url, callback) {
    post("parse_search_page.json", {"search_url": search_url}, function(err, body){
          return callback(body)
      })
  },
  get_current_subscriptions: function(id, callback) { 
	  get("get_current_subscriptions.json?id="+id, function(err, body){
		  return callback(body)
	  })
  },
  set_subscription_cadence: function(id, cadence, callback) { 
	  get("set_subscription_cadence.json?id="+id+"&cadence="+cadence, function(err, body){
		  return callback(body)
	  })
  },
  unsubscribe: function(id, callback) { 
	  get("unsubscribe.json?id="+id, function(err, body){
		  return callback(body)
	  })
  },
  create_subscription: function (customerInfo, callback) {
    post("create_subscription.json", customerInfo, function(err, body){
        return callback(body)
    })
  },
};
