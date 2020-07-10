package com.lookrative.globalchat2androidkotlin

import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import android.util.Log

class GlobalChat : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_global_chat)

        val ip = intent.getStringExtra("serverIp")
        val name = intent.getStringExtra("serverName")
        val port = intent.getIntExtra("serverPort", 0)

        Log.d("GlobalChatActivity", ""+ip)
        Log.d("GlobalChatActivity", ""+name)
        Log.d("GlobalChatActivity", ""+port)
    }
}