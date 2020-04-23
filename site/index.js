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
    try {
        var search_url = new URL(req.query.search_url)
        if (search_url.host != "trade-a-plane.com" && search_url.host != "www.trade-a-plane.com"){
          res.json({error: "Error! This URL doesn't look like it's from Trade-A-Plane:"+req.query.search_url+". Please provide a Trade-A-Plane search results URL"})
        } else if (search_url.pathname != "/search"){
          res.json({error: "Please provide a Trade-A-Plane search URL"})
        } else if (search_url.search.indexOf("s-type=aircraft") == -1){
          res.json({error: "Please provide a Trade-A-Plane search URL for aircraft only - this search doesn't look to be for aircraft."})
        } else {
          res.json({search_params: Array.from(search_url.searchParams), search_url: search_url.to_s}.to_json)
        }
    }
    catch(error) {
      res.json({error: "Error! Can't parse url that looks like:"+req.query.search_url+". Please provide a Trade-A-Plane search results URL"})
    }
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