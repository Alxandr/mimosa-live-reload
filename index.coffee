"use strict"

path = require 'path'
fs   = require 'fs'

logger =   require 'logmimosa'
watch =    require 'chokidar'
socketio = require 'socket.io'

config = require './config'

clientLibOutPath = null
clientLibText = null
sockets = {}
directoryWatchSetup  = false
connections = []

registration = (mimosaConfig, register) ->
  if mimosaConfig.isServer

    unless mimosaConfig.liveReload.enabled
      return logger.debug "Live-Reload is turned off, not registering reload functionality."

    register ['buildDone'],             'afterServer', _writeClientLibrary
    register ['buildDone'],             'afterServer', connect
    register ['add','update','remove'], 'afterWrite',  _writeClientLibrary
    register ['add','update','remove'], 'afterWrite',  _refreshPage

    clientLibOutPath = path.join mimosaConfig.watch.compiledJavascriptDir, 'reload-client.js'
    clientLibText =  fs.readFileSync path.join(__dirname, 'assets', 'reload-client.js'), 'ascii'

disconnect = ->
  for socketId, socket of sockets
    socket.emit 'remove'
    socket.disconnect()

  for conn in connections
    if conn.app?.removeAllListeners?
      conn.app.removeAllListeners()
    conn.connection.destroy()

connect = (mimosaConfig, options, next) ->
  unless options.userServer?
    return logger.warn "Live-Reload module is configured, but is unable to find your server.  Did you forget to return it from your startServer function? Disabling Live-Reload."

  io = if options.socketio?
    logger.debug "Using user's socketio"
    options.socketio
  else
    logger.debug "Using module's socketio"
    io = socketio.listen(options.userServer)
    io.enable 'browser client minification'
    io.enable 'browser client etag'
    io.enable 'browser client gzip'
    io.set 'log level', 1
    io

  options.userServer.on 'request', (request, response) ->
    connections.push request

  io.sockets.on 'connection', (socket) ->
    socket.on 'disconnect', ->
      delete sockets[socket.id] if sockets[socket.id]
    socket.on 'remove', ->
      delete sockets[socket.id] if sockets[socket.id]
    sockets[socket.id] = socket

  _setupDirectoryWatch(mimosaConfig.liveReload.additionalDirs) unless directoryWatchSetup

  next()

_setupDirectoryWatch = (dirsToWatch) ->
  if dirsToWatch? and dirsToWatch.length? > 0
    directoryWatchSetup = true
    watcher = watch.watch dirsToWatch, {persistent: true}
    watcher.on 'all', -> _emit 'page'
    watcher.on 'error', (error) ->
      # Doing nothing at the moment, just need to trap error event
      # console.log("ERROR: ", error)

_writeClientLibrary = (mimosaConfig, options, next) ->
  if options.userServer?
    fs.exists clientLibOutPath, (exists) ->
      if exists
        next()
      else
        logger.debug "Writing live reload client library to [[ #{clientLibOutPath} ]]"
        fs.writeFile clientLibOutPath, clientLibText, 'ascii', (err) ->
          if err
            logger.error err
          next()
  else
    next()

_refreshPage = (mimosaConfig, options, next) ->
  type = if options.isCSS then "css" else "page"
  _emit(type)
  next()

_emit = (type) ->
  logger.debug "Sending message to client to refresh page for type [[ #{type} ]]"
  Object.keys(sockets).forEach (s) ->
    sockets[s].emit type

module.exports =
  registration: registration
  defaults:     config.defaults
  placeholder:  config.placeholder
  validate:     config.validate
  connect:      connect
  disconnect:   disconnect