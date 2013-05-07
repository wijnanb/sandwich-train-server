querystring = require 'querystring'
https = require 'https'

hipchat = ->
    api_url = "https://api.hipchat.com/v1/rooms/message"
    api_params =
        format: 'json'
        auth_token: '1cd513768bb3823d484d836ca167f9'
        notify: 1
        message_format: 'text'
        room_id: 190791 #vikingco general

    send_message = (message, isUrgent) ->
        api_params.from = if isUrgent then "Train alert!" else "Train alert"
        api_params.color =  if isUrgent then "red" else "yellow"
        api_params.message = message

        url = api_url + "?" + querystring.stringify(api_params)

        console.log "hipchat message: " + message

        https.get(url, (res) ->
          console.log "hipchat response: " + res.statusCode
        ).on 'error', (e) ->
          console.log "hipchat error: " + e.message

    leaving = ->
        send_message("Watch out, the Sandwich Train is leaving in 2 minutes. Hurry up!", false)

    departed = ->
        send_message("Watch out, the Sandwich Train is leaving right NOW!", true)

    return public_methods =
        leaving: leaving
        departed: departed

module.exports = hipchat()