This is a redocumentation of the GlobalChat Draw (GlobalChat2) protocol.

# Client -> Server:

`REPORT::!!::handle::!!::b64string::!!::chat_token`

Report a user to the server.

* Handle - handle to report
* b64string - base64 libsodium sealed message contents
* chat_token - sending user's chat token

`GETBUFFER::!!::chat_token`

Get the current encrypted buffer (replay log).

`CLEARCANVAS::!!::chat_token`

(Server admin only) Clear the canvas for all users.

`DELETELAYERS::!!::handle::!!::chat_token`

(Server admin only) Delete handle's layers on the canvas for all users.

`BAN::!!::handle::!!::time::!!::chat_token`
`BAN::!!::handle::!!::chat_token`

(Server admin only) Ban handle's IP from the server for time minutes or permanently if time is omitted.

`UNBAN::!!::handle::!!::chat_token`

(Server admin only) Unban handle's IP from the server.

`MESSAGE::!!::b64string::!!::chat_token`

Send an encrypted message to the GlobalChat room using libsodium sealed boxes.

`KEY::!!::b64string`

Send our public key to the server for encrypted chat.

`SIGNON::!!::handle::!!::b64string`
`SIGNON::!!::handle`

Sign on as handle with an encrypted password or no password at all.

`SIGNOFF::!!::chat_token`

Sign off gracefully.

`GETHANDLES::!!::chat_token`

Get the currently online handles.

`PING::!!::chat_token`

Ping/pong mechanism, used to autoreconnect.

`PUBKEY::!!::b64_pub_key::!!::chat_token`

Share your E2E private message public key with other users using this command.

`PRIVMSG::!!::handle::!!::b64_cipher_text::!!::chat_token`

Send handle an E2E encrypted private message using their public key.

`GETPUBKEYS::!!::chat_token`

Get all users public keys for E2E private messages.

`GETPOINTS::!!::chat_token`

Let the server know you are ready to receive the Canvas points.

# Server -> Client

`KEY::!!::b64string`

Inform the client of the server's public key for sending encrypted contents.

`TOKEN::!!::chat_token::!!::handle::!!::server_name`

Server has welcomed you and given you a chat token to use to identify yourself to the server while telling you your handle and server name.

`HANDLES::!!::handles\n`

Server is returning the handles currently online, an text array separated by `\n`

`PONG::!!::handles\n`

Same as HANDLES but you will PING the server afterwards.

`BUFFER::!!::b64string`

Server is returning the replay buffer, encrypted with libsodium using your public key.

`CLEARTEXT`

Server wants your to clear your chat buffer and redownload the messages so something can be filtered.

`SAY::!!::handle::!!::b64string`

Handle just said b64string in the chat, libsodium encrypted with your public key.

`JOIN::!!::handle`

Inform the user that handle just joined the chat.

`LEAVE::!::handle`

Inform user that handle just left the chat.

`ALERT::!!::text`

Inform the user of a problem connecting to the server.

`PRIVMSG::!!::handle::!!::b64string`

You are receiving an encrypted private message from handle.

`CANVAS::!!::heightxwidth::!!::points_size`

Server is asking that you open a window heightxwidth to receive points_size points from the server and draw them.

`POINT::!!::x::!!::y::!!::dragging::!!::red::!!::green::!!::blue::!!::alpha::!!::width::!!::click_name`

Server is sending drawing information, specifically points to be connected into lines.

`CLEARCANVAS::!!::handle`

Handle is clearing the canvas.

`DELETELAYERS::!!::handle`

Delete handle's layers from the canvas. Currently clear canvas and get points due to optimizations.

`ENDPOINTS`

Server is informing you that the drawing is done sending and therefore should be loaded very soon.