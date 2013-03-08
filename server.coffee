express = require 'express'
fs = require 'fs'
path = require 'path'
eco = require 'eco'
io = require('socket.io').listen 8081

users = {}

server = express()

server.configure ->
    server.use '/static', express.static path.join(__dirname, '/static')
    server.use express.bodyParser()

io.sockets.on 'connection', (socket) ->
    socket.emit 'news', { hello: 'world' }
    socket.on 'my other event', (data) ->
    console.log data

server.get '/', (req, res) ->
    template = fs.readFileSync path.join(__dirname + "/index.eco.html"), "utf-8"
    context =
        socket_io_lib = "/socket.io/socket.io.js"
    res.send eco.render template, context



server.post '/hungry', (req, res) ->
    hungry = (req.body.hungry is 'true') or (req.body.hungry =='on')
    author = req.body.author or "Anonymous"

    console.log req.body

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

hungryCount = ->
    Object.keys(users).length or 0

isHungry = (author) ->
    if users.author? then true else false

setHungry = (author) ->
    users[author] =
        date: +new Date()
    update()

removeHungry = (author) ->
    delete users[author]
    update()

update = () ->
    count = hungryCount()
    status = 'waiting'
    countdown = 120

    if count >= 5
        status = 'ready'
        #tatus = 'running'

    current =
        status: status
        count: count
        countdown: countdown

    console.log "users", users
    console.log "update", current


server.listen 8080