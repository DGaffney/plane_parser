var config = require('../settings.json');
var qs = require('querystring')
const request = require('request');
const requestprom = require('request-promise')

function get(path, callback) {
  request({
    url: "https://"+config.api_host+":9292/"+path,
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
  ping: function (callback) {
      get("ping.json", function(err, body){
          callback(body)
      })
  },
  get_email_config: function (email_config_id, callback) {
      get("api/get_email_config.json?email_config_id="+email_config_id, function(err, body){
          callback(body)
      })
  },
  alter_email_config: function (query, callback) {
      email_settings = {
          "primary_events": query.primary_events,
          "attribute_updates": query.attribute_updates,
          "reviews": query.reviews,
          "search_ranks": query.search_ranks,
          "no_emails": query.no_emails,
          "email_config_id": query.email_config_id,
      }
      post("api/alter_email_config.json", email_settings, function(err, body){
          callback(body)
      })
  },
  store_email_config: function (email_config, callback) {
      post("store_email_config.json", email_config, function(err, body){
          callback(body)
      })
  },
  parse_search_page: function (search_url, callback) {
      search_url = search_url || ""
      post("parse_search_page.json", {"search_url": search_url}, function(err, body){
          callback(body)
      })
  },
  similar_businesses: function (params, callback) {
      post("api/similar_businesses.json", params, function(err, body){
          callback(body)
      })
  },
  notifications: function (business_id, callback) {
      get("api/notifications.json?business_id="+business_id, function(err, body){
          callback(body)
      })
  },
  unsubscribe: function (email_config_id, callback) {
      get("api/unsubscribe.json?email_config_id="+email_config_id, function(err, body){
          callback(body)
      })
  },
  start_tracking: function (email_config_id, callback) {
      get("api/start_tracking.json?email_config_id="+email_config_id, function(err, body){
          callback(body)
      })
  },
  link: function (params, callback) {
      get("api/link.json?"+qs.stringify(params), function(err, body){
          callback(body)
      })
  },
  track_open: function (email_id, config, callback) {
      get("api/track_open.json?email_id="+email_id+"&config="+config, function(err, body){
          callback(body)
      })
  },
  email_detail: function(email_id, format, callback) {
      get("api/email_detail.json?email_id="+email_id+"&format="+format, function(err, body){
          callback(body)
      })
  },
  full_notifications: function(email_config_id, format, callback) {
      get("api/full_detail.json?email_config_id="+email_config_id+"&format="+format, function(err, body){
          callback(body)
      })
  }
};
