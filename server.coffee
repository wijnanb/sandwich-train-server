express = require 'express'
fs = require 'fs'
path = require 'path'
eco = require 'eco'
io = require('socket.io').listen 8081

config =
    countdown: 12
    leaveat: 2

users = {}
socket = null

countdownStart = null
countdownInterval = null
countdownValue = config.countdown

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


server.post '/hungry', (req, res) ->
    hungry = (req.body.hungry is 'true') or (req.body.hungry =='on')
    author = req.body.author or "Anonymous"

    if hungry
        setHungry author
        message = "Ok, we heared you, author ##{author}: you are hungry!"
    else
        removeHungry author
        message = "We canceled your hunger request, author ##{author}"

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
    console.log "author", users[author]
    if users[author]? then true else false

setHungry = (author) ->
    users[author] =
        date: +new Date()
    update()

removeHungry = (author) ->
    delete users[author]
    update()

getStatus = (author=null)->
    count = hungryCount()
    status = 'waiting'
    countdown = countdownValue

    if count >= config.leaveat
        status = 'leaving'

        unless countdownStart?
            countdownStart = new Date()
            clearInterval countdownInterval

            countdownInterval = setInterval onCountdownUpdate, 1000

        if countdown <= 0
            status = 'departed'

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


onCountdownUpdate = ->
    diff = +new Date() - countdownStart.getTime()
    countdown = config.countdown - Math.round(diff/1000)

    console.log diff, diff, countdown
    countdownValue = countdown

    if countdown <= 0
        clearInterval countdownInterval
        console.log "finished!"

    update()





server.listen 8080