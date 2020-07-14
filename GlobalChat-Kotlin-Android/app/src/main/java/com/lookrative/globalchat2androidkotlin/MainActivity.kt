package com.lookrative.globalchat2androidkotlin

import android.content.Intent
import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import android.os.PersistableBundle
import android.util.Log
import android.widget.ArrayAdapter
import kotlinx.android.synthetic.main.activity_main.*
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import java.net.URL

var msl = "http://nexus-msl.herokuapp.com/msl"

class MainActivity : AppCompatActivity() {
    data class ServerListItem(
        val name: String,
        val ip: String,
        val port: Number
    ) {
        override fun toString(): String = name
    }

    var list : ArrayList<ServerListItem> = arrayListOf<ServerListItem>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        serverList.setOnItemClickListener { adapterView, view, i, l ->
            val listItem = list[i]

            // start the connection attempt


            // did it succeeed?

            // yes, change over


            val intent = Intent(this, GlobalChat::class.java)
            intent.putExtra("serverName", listItem.name)
            intent.putExtra("serverIp", listItem.ip)
            intent.putExtra("serverPort", listItem.port)
            startActivity(intent)
        }

        GlobalScope.launch {
            list.clear()

            URL(msl).readText().split("\n").forEach {
                var parts = it.split("::!!::")
                if (parts[0] == "SERVER" && parts.count() == 4) {
                    var item = ServerListItem(parts[1], parts[2], parts[3].toInt())
                    list.add(item)
                }

                runOnUiThread {
                    populateServerList(list)
                }
            }

        }
    }

    private fun populateServerList(servers : ArrayList<ServerListItem>) {
        serverList.adapter = ArrayAdapter<ServerListItem>(this, R.layout.server_list_item, servers)
    }
}