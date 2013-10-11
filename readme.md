sandwich-train
==============

The sandwich train is leaving!!! Tchoootchooo!


# Installation

You will need a Node.js installation (v >0.8)

Install dependencies:

    npm install

Compile coffeescripts: (with -b option!)

    node_modules/.bin/coffee -bc *.coffee

Run server:

    node server.js

Heroku compilation of coffeescripts:
heroku config:set BUILDPACK_URL=https://github.com/aergonaut/heroku-buildpack-coffeescript.git