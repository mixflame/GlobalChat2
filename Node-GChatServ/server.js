var GUID, buffer, handle_keys, handle_last_pinged, handles, log, net, p, password, port, scrollback, server_name, socket_keys, sockets, util;

net = require("net");

util = require("util");

Array.prototype.unique = function() {
  var key, output, value, _i, _ref, _results;
  output = {};
  for (key = _i = 0, _ref = this.length; 0 <= _ref ? _i < _ref : _i > _ref; key = 0 <= _ref ? ++_i : --_i) {
    output[this[key]] = this[key];
  }
  _results = [];
  for (key in output) {
    value = output[key];
    _results.push(value);
  }
  return _results;
};

Array.prototype.remove = function(element) {
  var e, i, _i, _len, _results;
  _results = [];
  for (i = _i = 0, _len = this.length; _i < _len; i = ++_i) {
    e = this[i];
    if (e === element) {
      _results.push(this.splice(i, 1));
    }
  }
  return _results;
};

GUID = function() {
  var S4;
  S4 = function() {
    return Math.floor(Math.random() * 0x10000).toString(16);
  };
  return S4() + S4() + "-" + S4() + "-" + S4() + "-" + S4() + "-" + S4() + S4() + S4();
};

log = function(msg) {
  return console.log("" + msg + "\n");
};

p = function(obj) {
  return log(util.inspect(obj));
};

handle_keys = {};

socket_keys = {};

handle_last_pinged = {};

handles = [];

sockets = [];

buffer = [];

sockets = [];

server_name = "GlobalChatNode";

password = "";

port = 9994;

scrollback = true;

net.createServer(function(socket) {
  var broadcast, broadcast_message, build_chat_log, build_handle_list, check_token, clean_handles, get_handle, parse_line, pong_me, remove_dead_socket, remove_user_by_handle, send_message, sock_send;
  socket.setTimeout(0);
  socket.setEncoding("utf8");
  broadcast = function(message, sender) {
    sockets.forEach(function(client) {
      if (client === sender) {
        return;
      }
      if (client.writable) {
        return client.write(message);
      }
    });
    return log(message);
  };
  remove_user_by_handle = function(handle) {
    var ct, ctkn, ctoken, nick;
    for (ct in handle_keys) {
      nick = handle_keys[ct];
      if (nick === handle) {
        ct = ct;
      }
    }
    for (socket in socket_keys) {
      ctkn = socket_keys[socket];
      if (ctkn === ct) {
        socket = socket;
      }
    }
    sockets.remove(socket);
    handles.remove(handle);
    for (ctoken in handle_keys) {
      handle = handle_keys[ctoken];
      if (ctoken === ct) {
        delete handle_keys[ctoken];
      }
    }
    for (socket in socket_keys) {
      ctoken = socket_keys[socket];
      if (ctoken === ct) {
        delete socket_keys[socket];
      }
    }
    try {
      return broadcast_message(socket, "LEAVE", [handle]);
    } catch (e) {
      return log("failed to broadcast LEAVE for clone handle " + handle);
    }
  };
  remove_dead_socket = function(socket) {
    var chattoken, ct, handle, _results;
    sockets.remove(socket);
    ct = socket_keys[socket];
    handle = handle_keys[ct];
    handles.remove(handle);
    for (chattoken in handle_keys) {
      handle = handle_keys[chattoken];
      if (chattoken === ct) {
        delete handle_keys[chattoken];
      }
    }
    _results = [];
    for (socket in socket_keys) {
      chattoken = socket_keys[socket];
      if (chattoken === ct) {
        _results.push(delete socket_keys[socket]);
      }
    }
    return _results;
  };
  check_token = function(chat_token) {
    var sender;
    sender = handle_keys[chat_token];
    return sender != null;
  };
  get_handle = function(chat_token) {
    var sender;
    sender = handle_keys[chat_token];
    return sender;
  };
  send_message = function(io, opcode, args) {
    var msg;
    msg = opcode + "::!!::" + args.join("::!!::");
    return sock_send(io, msg);
  };
  sock_send = function(io, msg) {
    msg = "" + msg + "\0";
    log(msg);
    if (io.writable) {
      return io.write(msg);
    }
  };
  broadcast_message = function(sender, opcode, args) {
    var msg;
    msg = opcode + "::!!::" + args.join("::!!::");
    return broadcast(msg, sender);
  };
  build_chat_log = function() {
    var displayed_buffer, msg, out, _i, _len;
    if (scrollback === false) {
      return "";
    }
    out = "";
    if (buffer.length > 30) {
      displayed_buffer = buffer.slice(buffer.length - 30, buffer.length);
    } else {
      displayed_buffer = buffer;
    }
    for (_i = 0, _len = displayed_buffer.length; _i < _len; _i++) {
      msg = displayed_buffer[_i];
      out += "" + msg[0] + ": " + msg[1] + "\n";
    }
    return out;
  };
  clean_handles = function() {
    var k, v, _results;
    _results = [];
    for (k in handle_keys) {
      v = handle_keys[k];
      if ((handle_last_pinged[k] != null) && handle_last_pinged[k] < (new Date().getTime() - 30 * 1000)) {
        _results.push(remove_user_by_handle(v));
      }
    }
    return _results;
  };
  build_handle_list = function() {
    return handles.unique().join("\n");
  };
  parse_line = function(line, io) {
    var chat_token, command, handle, msg, parr, pass;
    parr = line.split("::!!::");
    command = parr[0];
    if (command === "SIGNON") {
      handle = parr[1];
      pass = parr[2];
      if (handles.length !== 0 && handles.indexOf(handle) > 0) {
        send_message(io, "ALERT", ["Your handle is in use."]);
        io.close;
        return;
      }
      if (!(handle != null) || handle === "") {
        send_message(io, "ALERT", ["You cannot have a blank name."]);
        io.close;
        return;
      }
      if ((password === pass) || (!(pass != null) && (password === ""))) {
        chat_token = GUID();
        handle_keys[chat_token] = handle;
        socket_keys[io] = chat_token;
        handles.push(handle);
        sockets.push(io);
        send_message(io, "TOKEN", [chat_token, handle, server_name]);
        broadcast_message(io, "JOIN", [handle]);
      } else {
        send_message(io, "ALERT", ["Password is incorrect."]);
        io.close;
      }
      return;
    }
    chat_token = parr[parr.length - 1];
    if (check_token(chat_token)) {
      handle = get_handle(chat_token);
      if (command === "GETHANDLES") {
        return send_message(io, "HANDLES", [build_handle_list()]);
      } else if (command === "GETBUFFER") {
        buffer = build_chat_log();
        return send_message(io, "BUFFER", [buffer]);
      } else if (command === "MESSAGE") {
        msg = parr[1];
        buffer.push([handle, msg]);
        return broadcast_message(io, "SAY", [handle, msg]);
      } else if (command === "PING") {
        if (!(handles.indexOf(handle) > 0)) {
          handles.push(handle);
        }
        handle_last_pinged[handle] = new Date().getTime();
        return setTimeout(pong_me, 3000);
      } else if (command === "SIGNOFF") {
        broadcast_message(null, "LEAVE", [handle]);
        return socket.end;
      }
    }
  };
  pong_me = function() {
    return send_message(socket, "PONG", [build_handle_list()]);
  };
  sockets.push(socket);
  p(sockets);
  socket.on("data", function(data) {
    var line;
    line = data.match(/[^\0]+/).toString();
    log(line);
    return parse_line(line, socket);
  });
  return socket.on("end", function() {
    log("closing socket");
    log(socket);
    socket.end;
    return remove_dead_socket(socket);
  });
}).listen(port);

log("" + server_name + " running on GlobalChat2 3.0 platform Replay:" + scrollback + " Passworded:" + (password !== ''));