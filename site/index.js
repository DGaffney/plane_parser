const bodyParser = require('body-parser');
const request = require('request');
var express = require('express');
var app = express();
app.use(bodyParser.urlencoded({
	extended: false
}));

const logRequestStart = (req, res, next) => {
    console.info(`${req.method} ${req.originalUrl}`) 

    res.on('finish', () => {
        console.info(`${res.statusCode} ${res.statusMessage}; ${res.get('Content-Length') || 0}b sent; from ${req.headers.referer} on ${req.get('User-Agent')}`)
    })

    next()
}

app.use(logRequestStart)
var engines = require('consolidate');
app.engine('html', engines.mustache);
app.set('view engine', 'html');
app.use(bodyParser.json());
var http = require('http').Server(app);
var STRIPE_API = require('./stripe-functions.js');
var api = require("./api.js")

f = require('util').format,

// app.use(express.static('files'))
http.listen(8080, function() {
	console.log('listening on *:8080');
});
const trackImg = new Buffer('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7', 'base64');

app.get('/image/:email_id', (req, res) => {
  if (req.headers.referer == null){
      res.writeHead(200, {
      'Content-Type': 'image/gif',
      'Content-Length': trackImg.length
    });
    const email_id = req.params
    config = req.query.config
    api.track_open(email_id, config, function(body){
        res.end(trackImg)
    })
  } else {
      res.end(trackImg)
  }
})
app.get("/parse_search_page.json", function(req, res) {
    //body_params = JSON.parse(request.body.read)
    //search_url = URI.parse(URI.decode(body_params["search_url"])) rescue nil
    //return {error: "Error! Can't parse url that looks like: #{body_params["search_url"]}. Please provide a Trade-A-Plane search results URL"}.to_json if search_url.nil? || !search_url.host.include?("trade-a-plane.com")
    //return {error: "Please provide a Trade-A-Plane search URL"}.to_json if search_url.path != "/search"
    //return {error: "Please provide a Trade-A-Plane search URL for aircraft only - this search doesn't look to be for aircraft."}.to_json if !search_url.query.include?("s-type=aircraft")
    //return {search_params: URI.decode_www_form(search_url.query), search_url: search_url.to_s}.to_json
    console.log(req.query.search_url)
    api.parse_search_page(req.query.search_url, function(body){
        res.send(body)
    })
})
app.post('/handlePayment', async (req, res) => {
  const customerInfo = {
    name: req.body.name,
    email: req.body.email,
    planId: req.body.plan,
  };

  const subscription = await STRIPE_API.createCustomerAndSubscription(
    req.body.paymentMethodId,
    customerInfo,
  );

  return res.json({ subscription });
});

app.get("/start_signup.json", async (req, res) => {
  const products = await STRIPE_API.getProductsAndPlans();
  res.send(products)
});
app.post("/signup.json", function(req, res){
    email_config = req.body
    email_config.updated_at = email_config.created_at = new Date()
    api.store_email_config(email_config, function(req, res){
    })
})
app.get("/unsubscribe.json", function(req, res){
    api.unsubscribe(req.email_config_id, function(body){
        res.send(body)
    })
})
app.get("/about", function(req, res){
    res.render("./../www/about.html", {})
})
app.get("/privacy", function(req, res){
    res.render("./../www/privacy.html", {})
})
app.get("/unsubscribe/:email_config_id", function(req, res){
    api.unsubscribe(req.params.email_config_id, function(body){
        res.render("./../www/unsubscribed.html")
    })
})
app.use('/', express.static('www'));
app.use(function (req, res, next) {
  res.status(404).render("./../www/404.html", {})
})