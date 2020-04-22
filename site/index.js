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
    })
    const { email_id } = req.params
    config = req.query.config
    api.track_open(email_id, config, function(body){
        res.end(trackImg)
    })
  } else {
      res.end(trackImg)
  }
})
app.get("/lookup_business.json", function(req, res) {
    api.lookup_business(req.query.name, req.query.location, function(body){
        res.send(body)
    })
})
app.post("/similar_businesses.json", function(req, res) {
    api.similar_businesses(req.body, function(body){
        res.send(body)
    })
})
app.get("/notifications.json", function(req, res) {
    api.notifications(req.query.business_id, function(body){
        res.send(body)
    })
})
app.get("/email_detail.json", function(req, res) {
    api.email_detail(req.query.email_id, 'json', function(body){
        res.send(body)
    })
})
app.get("/full_notification_download.json", function(req, res) {
    api.full_notifications(req.query.email_config_id, 'csv', function(body){
        res.writeHead(200, {'Content-Type': 'application/force-download','Content-disposition':'attachment; filename=localet_email_'+req.query.email_config_id+'.csv'});
        res.end(body.result);
    })
})
app.get("/email_detail_download.json", function(req, res) {
    api.email_detail(req.query.email_id, 'csv', function(body){
        res.writeHead(200, {'Content-Type': 'application/force-download','Content-disposition':'attachment; filename=localet_email_'+req.query.email_id+'.csv'});
        res.end(body.result);
    })
})
app.get("/email_config.json", function(req, res) {
    api.notifications(req.query.email_config_id, function(body){
        res.send(body)
    })
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
app.post("/alter_email.json", function(req, res){
    api.alter_email_config(req.body, function(body){
        res.send(body)
    })
})
app.get("/manage_alerts/:email_config_id", function(req, res){
    api.get_email_config(req.params.email_config_id, function(body){
        context = {
            email_config_id: body._id["$oid"],
            primary_events: body.primary_events,
            attribute_updates: body.attribute_updates,
            reviews: body.reviews,
            search_ranks: body.search_ranks,
            subscribed: !body.subscribed,
        }
        res.render("./../www/update_email.html", context)
    })
})
app.get("/about", function(req, res){
    res.render("./../www/about.html", {})
})
app.get("/privacy", function(req, res){
    res.render("./../www/privacy.html", {})
})
app.get("/full_notifications/:email_config_id", function(req, res){
    api.full_notifications(req.params.email_config_id, 'html', function(body){
        context = {
            email_config_id: req.params.email_config_id,
            date: body.created_at,
            primary_events: body.result["Big Events"],
            attribute_updates: body.result["Page Updates"],
            reviews: body.result["New Reviews"],
            search_ranks: body.result['Search Result Rankings'],
        }
        res.render("./../www/full_notifications.html", context)
    })
})
app.get("/email_detail/:email_id", function(req, res){
    api.email_detail(req.params.email_id, 'html', function(body){
        context = {
            email_id: req.params.email_id,
            email_config_id: body.email_config_id["$oid"],
            date: body.created_at,
            primary_events: body.result["Big Events"],
            attribute_updates: body.result["Page Updates"],
            reviews: body.result["New Reviews"],
            search_ranks: body.result['Search Result Rankings'],
        }
        res.render("./../www/email_detail.html", context)
    })
})
app.get("/start_tracking/:email_config_id", function(req, res){
    api.start_tracking(req.params.email_config_id, function(body){
        context = {
            email_config_id: req.params.email_config_id,
            business: body.business,
            tracked_businesses: body.tracked_businesses,
            email_address: body.email_address,
            marketing_lead_id: body.marketing_lead_id
        }
        res.render("./../www/start_tracking.html", context)
    })
})
app.get("/unsubscribe/:email_config_id", function(req, res){
    api.unsubscribe(req.params.email_config_id, function(body){
        res.render("./../www/unsubscribed.html")
    })
})
app.get("/link", function(req, res){
    api.link(req.query, function(body){
        res.redirect(body.link)
        console.log("successfully done")
    })
})
app.use('/', express.static('www'));
app.use(function (req, res, next) {
  res.status(404).render("./../www/404.html", {})
})