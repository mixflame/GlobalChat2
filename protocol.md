This is a redocumentation of the GlobalChat Draw (GlobalChat2) protocol.

Client -> Server:

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

