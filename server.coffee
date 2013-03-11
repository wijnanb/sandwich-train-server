config = require('./config.js').config
express = require 'express'
fs = require 'fs'
path = require 'path'
eco = require 'eco'
io = require('socket.io').listen config.sockets_port

config.countdown = 120 # 2minutes
config.leaveat = 5
config.resetAllDelay = 1*60*1000 # 1 minuut

users = {}
socket = null

countdownStart = null
countdownTimerID = null
countdownValue = config.countdown
resetTimerID = null

server = express()

server.configure ->
    server.use '/static', express.static path.join(__dirname, '/static')
    server.use express.bodyParser()

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
            clearInterval countdownTimerID

            countdownTimerID = setInterval onCountdownUpdate, 1000

        if countdown <= 0
            status = 'departed'

            unless previousStatus is 'departed'
                console.log "START RESET TIMER"
                clearTimeout resetTimerID
                resetTimerID = setTimeout reset, config.resetAllDelay

    unless status is 'departed'
        clearTimeout resetTimerID


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

    console.log "users", users
    console.log "update", status

    io.sockets.emit 'update', status

reset = ->
    console.log "RESET"
    users = {}
    socket = null
    clearTimeout resetTimerID
    clearInterval countdownTimerID
    countdownStart = null
    countdownTimerID = null
    countdownValue = config.countdown

    update()

onCountdownUpdate = ->
    diff = +new Date() - countdownStart.getTime()
    countdown = config.countdown - Math.round(diff/1000)

    console.log diff, diff, countdown
    countdownValue = countdown

    if countdown <= 0
        clearInterval countdownTimerID
        console.log "finished!"

    update()


console.log "listening on port " + config.server_port
server.listen config.server_port