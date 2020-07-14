package com.lookrative.globalchat2androidkotlin

import android.os.Build
import android.widget.ArrayAdapter
import android.widget.TextView
import androidx.annotation.RequiresApi
import kotlinx.android.synthetic.main.activity_global_chat.*
import kotlinx.android.synthetic.main.activity_main.*
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import java.nio.channels.AsynchronousCloseException
import java.nio.channels.AsynchronousSocketChannel
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.PrivateKey
import java.security.PublicKey
import java.util.*
import java.util.concurrent.ExecutionException
import java.util.concurrent.Future
import javax.crypto.KeyAgreement

@RequiresApi(Build.VERSION_CODES.O)
class GC2Client(private val globalChat: GlobalChat, private val ip: String?, private val port: Int) {
    private lateinit var connFuture: Future<Void>
    private lateinit var nicks: Sequence<String>
    private var stopping: Boolean = false
    private val keyPair = KeyPairGenerator.getInstance("EC").generateKeyPair()
    private lateinit var lastPing: Date
    private var connected: Boolean = false
    private lateinit var serverName: String
    private lateinit var handle: String
    private lateinit var token: String

    private val channel = AsynchronousSocketChannel.open()
    private val charset = Charsets.UTF_8

    data class UserListItem(
        val handle: String
    ) {
        override fun toString(): String = handle
    }

    var userList : ArrayList<UserListItem> = arrayListOf<UserListItem>()

    fun start() {
        println("Connecting to $ip:$port")
        connFuture = channel.connect(InetSocketAddress(ip, port))
        connFuture.get()
        if (channel.remoteAddress == null) {
            TODO("Go back on failure")
            return
        }

        GlobalScope.launch {
            var message = ""
            while (!stopping && channel.isOpen) {
                val buf = ByteBuffer.allocate(256)
                try {
                    val readlen = channel.read(buf).get()
                    if (readlen > 0) {
                        buf.flip()
                        charset.decode(buf).toString().forEach { char ->
                            if (char == '\u0000') {
                                parseLine(message)
                                message = ""
                            } else {
                                message += char
                            }
                        }
                    }
                } catch (ex: ExecutionException) {
                    // pass
                }
            }
        }

        sendMessage("SIGNON", listOf("kotlin"))

        globalChat.sendButton.setOnClickListener {
            val mesg = globalChat.input.text.toString()

            if (mesg.length == 0)
                return@setOnClickListener

            println("im about to send message $mesg")
            globalChat.input.text.clear()

            GlobalScope.launch {
                sendMessage("MESSAGE", listOf(mesg, token))
                addMsg(handle, mesg)
            }

        }
    }

    private fun parseLine(dat: String) {
        val parr = dat.splitToSequence("::!!::")
        val cmd : String = parr.elementAt(0)
        when (cmd) {
            "TOKEN" -> {
                token = parr.elementAt(1).toString()
                println("THIS IS MY MTOKEN $token")
                handle = parr.elementAt(2).toString()
                serverName = parr.elementAt(3).toString()
                ping()
                showChat()
                getLog()
                getHandles()
                getPubKeys()
                sendPubKey()
                connected = true
            }
            "CANVAS" -> {
//                let width = parr[1].components(separatedBy: "x")[0]
//                let height = parr[1].components(separatedBy: "x")[1]
//                open_draw_window(Int(width)!, Int(height)!)
            }
            "BUFFER" -> {
                val buffer : String = parr.elementAt(1)
                if (buffer != "") {
                    for (line in buffer.lines()) {
                        outputToChatWindow(line)
                    }
                    updateAndScroll()
                }
            }
            "HANDLES" -> {
                nicks = parr.last().toString().splitToSequence("\n")
                updateNickList()
            }
            "PUBKEY" -> {

            }
            "PONG" -> {
                nicks = parr.last().toString().splitToSequence("\n")
                updateNickList()
                ping()
            }
            "SAY" -> {
                val handle = parr.elementAt(1)
                val msg = parr.elementAt(2)
                addMsg(handle, msg)
            }
            else -> {
                println("UNKNOWN COMMAND $cmd")
            }
        }
    }

    private fun addMsg(handle: String, msg: String) {
        //checkIfPinged()
        //checkIfAwayOrBack()
        val msg = "$handle: $msg\n"
        outputToChatWindow(msg)
    }

    private fun outputToChatWindow(msg: String) {
        println("Appending to chat window... $msg")
        //globalChat.chat.append(msg)
        //globalChat.webView.loadDataWithBaseURL(null, "<p>$msg</p>", "text/html", "UTF-8", "about:blank")

        val sani = msg.replace("'", "\\\'")

        // VERY UNSAFE!!!!

        globalChat.runOnUiThread {
            globalChat.webView.loadUrl("javascript:appendText('$sani')")
        }

        //globalChat.chat.text = globalChat.chat.text.toString() + msg;
        updateAndScroll()
    }

    private fun updateNickList() {
        userList.clear()
        for (nick in nicks) {
            val user = UserListItem(nick)
            userList.add(user)
        }
        globalChat.runOnUiThread {
            globalChat.usersList.adapter = ArrayAdapter<UserListItem>(globalChat,
                R.layout.user_list_item, userList)
        }
    }

    private fun updateAndScroll() {
        globalChat.runOnUiThread {
            globalChat.webView.scrollTo(0, 999999999)
        }
    }

    private fun sendPubKey() {
        val out = Base64.getEncoder().encodeToString(keyPair.private.encoded)
        sendMessage("PUBKEY", listOf(out, token))
    }

    private fun getPubKeys() {
        sendMessage("GETPUBKEYS", listOf(token))
    }

    private fun getHandles() {
        sendMessage("GETHANDLES", listOf(token))
    }

    private fun getLog() {
        sendMessage("GETBUFFER", listOf(token))
    }

    private fun showChat() {
        globalChat.runOnUiThread {
            globalChat.title = serverName
        }
    }

    private fun ping() {
        lastPing = Date()
        sendMessage("PING", listOf(token))
    }

    private fun sendMessage(opcode: String, args: List<String>) {
        write(listOf(opcode).union(args).joinToString("::!!::")+"\u0000")
    }

    private fun write(s: String) {
        val buff = ByteBuffer.wrap(s.toByteArray(charset))
        println("writing $s")
        val fut = channel.write(buff)
        fut.get()
    }

    fun stop() {
        if (connected)
            channel.close()
        else if (!connFuture.isDone)
            connFuture.cancel(true)
        stopping = true
    }
}