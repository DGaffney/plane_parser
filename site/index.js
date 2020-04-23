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
var api = require("./api.js")
var stripe = require('stripe')(api.settings.stripe_secret);

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
    api.parse_search_page(req.query.search_url, function(body){
        res.send(body)
    })
})
app.get("/start_signup.json", function(req, res){

  stripe.checkout.sessions.create(
    {
      success_url: 'https://tapdeals.cognitivesurpl.us/success?session_id={CHECKOUT_SESSION_ID}',
      cancel_url: 'https://tapdeals.cognitivesurpl.us/cancel',
      payment_method_types: ['card'],
      line_items: [{
        plan: api.settings.email_subscription_product_id,
      }],
    },
    function(err, session) {
      console.log(session)
      res.send(session)
    }
  );
})
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