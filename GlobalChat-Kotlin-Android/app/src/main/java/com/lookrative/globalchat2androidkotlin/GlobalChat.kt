package com.lookrative.globalchat2androidkotlin

import android.content.Intent
import android.os.Build
import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import androidx.annotation.RequiresApi
import kotlinx.android.synthetic.main.activity_global_chat.*
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch

@RequiresApi(Build.VERSION_CODES.O)
class GlobalChat : AppCompatActivity() {
    private lateinit var client : GC2Client

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_global_chat)

        val ip = intent.getStringExtra("serverIp")
        val name = intent.getStringExtra("serverName")
        val port = intent.getIntExtra("serverPort", 0)

        webView.settings.javaScriptEnabled = true;
        webView.loadUrl("file:///android_asset/chat.html")

        client = GC2Client(this, ip, port)
        GlobalScope.launch {
            client.start()
        }

        println("ON ACTIVITY CREATE")
    }

    override fun onActivityReenter(resultCode: Int, data: Intent?) {
        super.onActivityReenter(resultCode, data)

        println("ON ACTIVITY REENTER")
    }

    override fun onBackPressed() {
        println("ON BACK PRESSED")
        GlobalScope.launch {
            client.stop()
        }
        super.onBackPressed()
    }
}