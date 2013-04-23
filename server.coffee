config = require('./config.js').config
express = require 'express'
fs = require 'fs'
path = require 'path'
eco = require 'eco'
io = require('socket.io').listen config.sockets_port
log4js = require('log4js')
log4js.replaceConsole()

users = {}
socket = null

countdownStart = null
countdownIntervalID = null
countdownValue = config.countdown
resetTimeoutID = null

io.enable 'browser client minification'         # send minified client
io.enable 'browser client etag'                 # apply etag caching logic based on version number
io.enable 'browser client gzip'                 # gzip the file
io.set 'log level', config.log_level
io.set 'transports', config.transports

server = express()

server.configure ->
    server.use '/static', express.static path.join(__dirname, '/static')
    server.use express.bodyParser()
    server.use (req, res, next) ->
        res.header 'Access-Control-Allow-Origin', config.allowedDomains
        res.header 'Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE'
        res.header 'Access-Control-Allow-Headers', 'Content-Type'
        next()

server.get '/', (req, res) ->
    template = fs.readFileSync path.join(__dirname + "/index.eco.html"), "utf-8"
    context = {}
    res.send eco.render template, context

server.get '/channel', (req, res) ->
    template = fs.readFileSync path.join(__dirname + "/channel.eco.html"), "utf-8"
    context = {}
        #socket_io_lib = "/socket.io/socket.io.js"
    res.send eco.render template, context

server.post '/reset', (req, res) ->
    reset()
    res.json getStatus()

server.post '/hungry', (req, res) ->
    hungry = (req.body.hungry is 'true') or (req.body.hungry =='on')
    author = req.body.author or "Anonymous"
    status = getStatus().status

    if hungry
        setHungry author
        message = "Ok, we heared you: you are hungry!"
    else
        unless status is 'leaving'
            removeHungry author
            message = "We canceled your hunger request"
        else
            message = "The train is already about to leave, too late to cancel now"

    res.json
        author: author,
        hungry: hungry,
        message: message,
        count: hungryCount()

server.post '/status', (req, res) ->
    author = req.body.author or null
    res.json getStatus(author)

hungryCount = ->
    Object.keys(users).length or 0

isHungry = (author) ->
    if users[author]? then true else false

setHungry = (author) ->
    users[author] =
        date: +new Date()
    update()

removeHungry = (author) ->
    unless getStatus().status is 'leaving'
        delete users[author]
        update()

getStatus = (author=null)->
    previousStatus = status

    count = hungryCount()
    status = 'waiting'
    countdown = countdownValue

    if count >= config.leaveat
        status = 'leaving'

        unless countdownStart?
            countdownStart = new Date()
            clearInterval countdownIntervalID

            countdownIntervalID = setInterval onCountdownUpdate, 1000

        if countdown <= 0
            status = 'departed'

            unless previousStatus is 'departed'
                console.log "START RESET TIMER -> call reset in " + config.resetAllDelay + "s"
                clearTimeout resetTimeoutID
                resetTimeoutID = setTimeout reset, config.resetAllDelay*1000

    unless status is 'departed'
        clearTimeout resetTimeoutID


    current =
        status: status
        count: count
        countdown: countdown

    if author
        current.author = author
        current.hungry = isHungry(author)

    return current

update = ->
    status = getStatus()
    console.log "update", status

    io.sockets.emit 'update', status

reset = ->
    console.log "RESET"
    users = {}
    socket = null
    clearTimeout resetTimeoutID
    clearInterval countdownIntervalID
    countdownStart = null
    countdownIntervalID = null
    countdownValue = config.countdown

    update()

onCountdownUpdate = ->
    diff = +new Date() - countdownStart.getTime()
    countdown = config.countdown - Math.round(diff/1000)

    countdownValue = countdown

    if countdown <= 0
        clearInterval countdownIntervalID
        console.log "finished!"

    update()


console.log "http server running on port " + config.server_port
console.log "sockets server running on port " + config.sockets_port
server.listen config.server_port