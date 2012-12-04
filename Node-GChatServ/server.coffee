#!/usr/bin/env coffee

# GC2-Node
# Ugly mess of a program, I'll admit it
# But it works.
# Full support for GC2 Protocol v3
# Support: Scrollback. Logsaving. Nexus Pinging. Arguments.
# Coming soon: Nothing.

net = require("net")
util = require("util")
http = require("http")
fs = require("fs")

Array::unique = ->
  output = {}
  output[@[key]] = @[key] for key in [0...@length]
  value for key, value of output

Array::remove = (element) ->
  for e, i in this when e is element
    this.splice(i, 1)

GUID = ->
  S4 = ->
    Math.floor(Math.random() * 0x10000).toString 16
  S4() + S4() + "-" + S4() + "-" + S4() + "-" + S4() + "-" + S4() + S4() + S4()

log = (msg) ->
  #unless msg.indexOf('PING') > 0 || msg.indexOf('PONG') > 0
  util.log "#{msg}\n"

p = (obj) ->
  log util.inspect(obj)

buffer = []
sockets = []
host = process.argv[2] # 'localhost'
port = parseInt(process.argv[3]) # 9994
server_name = process.argv[4]
password = process.argv[5] || ""
is_private = process.argv[6] == "true"
scrollback = process.argv[7] == "true"

handle_keys = {}
socket_keys = {}
handle_last_pinged = {}
handles = []
sockets = []

# p is_private


ping_nexus = ->
  if is_private == false
    log "Pinging NexusNet that I'm Online!!"
    req = http.get("http://nexusnet.herokuapp.com/online?name=#{server_name}&host=#{host}&port=#{port}", (res) ->
      log "Nexus Pinged."
    )

nexus_offline = ->
  if is_private == false
    log "Informing NexusNet that I have exited!!!"
    req = http.get("nexusnet.herokuapp.com", "/offline_by_name?name=#{server_name}", (res) ->
      log "Nexus informed."
    )

save_chat_log = ->
  fs.mkdir "tmp", ->
    fs.writeFile "tmp/#{server_name}.log", build_chat_log(), (err) ->
      if err
        log err
      else
        log "saved chatlog"

load_chat_log = ->
  fs.exists "tmp/#{server_name}.log", (exists) ->
    if exists == true
      fs.readFile "tmp/#{server_name}.log", (err, data) ->
        throw err if err
        for msgstr in data.toString().split("\n")
          break if msgstr == ''
          msg = msgstr.split(": ")
          buffer.push [msg[0], msg[1]]

load_chat_log()

broadcast = (message, sender) ->
  for s in sockets when s isnt sender
    sock_send s, message
  p message
remove_user_by_handle = (handle) ->
  ct = ct for ct, nick of handle_keys when nick is handle
  socket = socket for socket, ctkn of socket_keys when ctkn is ct
  sockets.remove socket
  handles.remove handle
  delete handle_keys[ctoken] for ctoken, handle of handle_keys when ctoken is ct
  delete socket_keys[socket] for socket, ctoken of socket_keys when ctoken is ct
  try
    broadcast_message(socket, "LEAVE", [handle])
  catch e
    log "failed to broadcast LEAVE for clone handle #{handle}"
remove_dead_socket = (socket) ->
  sockets.remove socket
  ct = socket_keys[socket]
  handle = handle_keys[ct]
  handles.remove handle
  delete handle_keys[chattoken] for chattoken, handle of handle_keys when chattoken is ct
  delete socket_keys[socket] for socket, chattoken of socket_keys when chattoken is ct
check_token = (chat_token) ->
  sender = handle_keys[chat_token]
  return sender?
get_handle = (chat_token) ->
  sender = handle_keys[chat_token]
  return sender
send_message = (io, opcode, args) ->
  msg = opcode + "::!!::" + args.join("::!!::")
  sock_send io, msg
sock_send = (io, msg) ->
  p msg
  msg = "#{msg}\0"
  if io? && io.writable
    io.write msg
broadcast_message = (sender, opcode, args) ->
  msg = opcode + "::!!::" + args.join("::!!::")
  broadcast msg, sender
build_chat_log = ->
  return "" if scrollback == false
  out = ""
  if buffer.length > 30
    displayed_buffer = buffer.slice(buffer.length-30, buffer.length)
  else
    displayed_buffer = buffer
  displayed_buffer.forEach (msg) ->
    out += "#{msg[0]}: #{msg[1]}\n"
  out
clean_handles = ->
  remove_user_by_handle(v) for k, v of handle_keys when (handle_last_pinged[k]? && handle_last_pinged[k] < (new Date().getTime() - 30*1000))
build_handle_list = ->
  return handles.unique().join("\n")
parse_line = (line, io) ->
  parr = line.split("::!!::")
  command = parr[0]
  if command == "SIGNON"
    handle = parr[1]
    pass = parr[2]
    if handles.length != 0 && handles.indexOf(handle) > 0
      send_message(io, "ALERT", ["Your handle is in use."])
      io.close
      return
    if !handle? || handle == ""
      send_message(io, "ALERT", ["You cannot have a blank name."])
      #remove_dead_socket io
      io.close
      return
    if ((password == pass) || (!(pass?) && (password == "")))
      # uuid are guaranteed unique
      chat_token = GUID()
      handle_keys[chat_token] = handle
      socket_keys[io] = chat_token
      handles.push handle
      send_message(io, "TOKEN", [chat_token, handle, server_name])
      broadcast_message(io, "JOIN", [handle])
    else
      send_message(io, "ALERT", ["Password is incorrect."])
      io.close
    return

  # auth
  chat_token = parr[parr.length - 1]

  if check_token(chat_token)
    handle = get_handle(chat_token)
    if command == "GETHANDLES"
      send_message(io, "HANDLES", [build_handle_list()])
    else if command == "GETBUFFER"
      out = build_chat_log()
      send_message(io, "BUFFER", [out])
    else if command == "MESSAGE"
      msg = parr[1]
      buffer.push [handle, msg]
      broadcast_message(io, "SAY", [handle, msg])
    else if command == "PING"
      unless handles.indexOf(handle) > 0
        handles.push handle
      handle_last_pinged[handle] = new Date().getTime()
    else if command == "SIGNOFF"
      handles.remove handle
      broadcast_message(null, "LEAVE", [handle])
      io.end
pong_everyone = ->
  if sockets.length > 0 && handles.length > 0
    broadcast_message(null, "PONG", [build_handle_list()])
    clean_handles

# start the server

server = net.createServer((socket) ->
  socket.setTimeout 0
  socket.setEncoding "utf8"
  socket.setKeepAlive true
  socket.setNoDelay false
  sockets.push socket

  socket.on "data", (data) ->
    line = data.match(/[^\0]+/).toString() #magic part
    p line
    parse_line line, socket

  socket.on "end", ->
    log "FIN recvd"
    socket.end
    remove_dead_socket(socket)

).listen port

log "#{server_name} running on GC2-Node at #{host}:#{port} Replay:#{scrollback} Passworded:#{password != ''} Private:#{is_private}"

ping_nexus()

# timers

setInterval(pong_everyone, 5000)
setInterval(save_chat_log, 30000)

# crash/exit

# process.on('uncaughtException', (e) ->
#   log "Uncaught #{e}.. Crashing"
#   # unless is_private?
#   nexus_offline()
#   save_chat_log()
# )

# process.on('SIGTERM', ->
#   log "Terminated."
#   # unless is_private?
#   nexus_offline()
#   save_chat_log()
# )

process.on('exit', ->
  log "Terminated."
  nexus_offline()
  save_chat_log()
)