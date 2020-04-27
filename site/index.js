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
app.get("/parse_search_page.json", function(req, res) {
    try {
        var search_url = new URL(req.query.search_url)
        if (search_url.host != "trade-a-plane.com" && search_url.host != "www.trade-a-plane.com"){
          return res.json({error: "Error! This URL doesn't look like it's from Trade-A-Plane:"+req.query.search_url+". Please provide a Trade-A-Plane search results URL"})
        } else if (search_url.pathname != "/search" && search_url.pathname != "/filtered/search"){
          return res.json({error: "Please provide a Trade-A-Plane search URL"})
        } else if (search_url.search.indexOf("s-type=aircraft") == -1){
          return res.json({error: "Please provide a Trade-A-Plane search URL for aircraft only - this search doesn't look to be for aircraft."})
        } else {
          return res.json({search_params: Array.from(search_url.searchParams), search_url: String(search_url)})
        }
    }
    catch(error) {
      return res.json({error: "Error! Can't parse url that looks like:"+req.query.search_url+". Please provide a Trade-A-Plane search results URL"})
    }
})
app.post('/handle_payment.json', async (req, res) => {
	try {
	    const customerInfo = {
	      name: req.body.name,
	      email: req.body.email,
	      planId: req.body.plan,
	    };

	    const subscription = await STRIPE_API.createCustomerAndSubscription(
	      req.body.paymentMethodId,
	      customerInfo,
	    );
	    customerInfo.searchUrl = req.body.search_url
	    customerInfo.subscription = subscription
	    api.create_subscription(customerInfo, function(body){
	      return res.json({ subscription });
	    })
	} catch(error) {
		console.log(error)
		return res.status(500).send({
		   message: 'This is an error!'
		});
	}
});

//app.get("/products.json", async (req, res) => {
//  const products = await STRIPE_API.getProductsAndPlans();
//  res.send(products)
//});

app.get("/get_current_subscriptions.json", function(req, res){
	api.get_current_subscriptions(req.query.id, function(body){
		return res.json(body)
	})
});

app.get("/set_subscription_cadence.json", function(req, res){
	api.set_subscription_cadence(req.query.id, req.query.cadence, function(body){
		return res.json(body)
	})
});

app.get("/unsubscribe.json", function(req, res){
	api.unsubscribe(req.query.id, function(body){
		return res.json(body)
	})
});
  
  
  
app.get("/about", function(req, res){
    res.render("./../www/about.html", {})
})

app.get("/manage", function(req, res){
    res.render("./../www/manage.html", {})
})

app.get("/privacy", function(req, res){
    res.render("./../www/privacy.html", {})
})

app.use('/', express.static('www'));
app.use(function (req, res, next) {
  res.status(404).render("./../www/404.html", {})
})