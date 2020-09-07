package io.abner.flutter_js

import android.util.Log
import de.prosiebensat1digital.oasisjsbridge.*
import kotlinx.coroutines.Dispatchers
import java.util.logging.Logger


class JSEngine(context: android.content.Context) {

    private var runtime: JsBridge = JsBridge(JsBridgeConfig.standardConfig())
    private var messageChannelMap = mutableMapOf<String, (message: String) -> String>()

    fun getRuntime(): JsBridge {
        return runtime
    } 

    var runtimeInitialized = false
    val host = "localhost"

    val port = 0
    init {

        val errorListener = object : JsBridge.ErrorListener(Dispatchers.Main) {
            override fun onError(error: JsBridgeError) {
                Log.e("MainActivity", error.errorString())
            }
        }
        runtime.registerErrorListener(errorListener)

        val sendMessage = JsValue.fromNativeFunction2(runtime) { channelName: String, message: String ->

            try {
                if (messageChannelMap.containsKey(channelName)) {
                    messageChannelMap.getValue(channelName).invoke(message);
                } else {
                    Log.i("SendMessage Channel", "Channel ${channelName} wasn't registered!")
                }

                return@fromNativeFunction2 "$channelName:$message"
            } catch (e: Exception) {
                return@fromNativeFunction2 e.message
            }
            
        }.assignToGlobal("FLUTTERJS_sendMessage")

        runtime.evaluateBlocking(
                """
                    var FLUTTERJS_pendingMessages = {};
                    function FLUTTERJS_uuidv4() {
                      return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
                        var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
                        return v.toString(16);
                      });
                    }
                    function sendMessage(channel, message) {
                        var idMessage = FLUTTERJS_uuidv4();
                        return new Promise((resolve, reject) => {
                            FLUTTERJS_pendingMessages[idMessage] = { 
                                resolve: (v) => { resolve(v); return v;}, 
                                reject: reject
                            };
                            FLUTTERJS_sendMessage(channel, JSON.stringify({ id: idMessage, message: message }) );
                        });
                    }
                """.trimIndent(),
                JsonObjectWrapper::class.java
        )
    }

    fun registerChannel(channelName: String, channelFn: (message: String) -> String) {
        messageChannelMap[channelName] = channelFn
    }

    fun eval(script: String): JsonObjectWrapper {
        return runtime.evaluateBlocking(script, JsonObjectWrapper::class.java) as JsonObjectWrapper
    }

    fun release() {
        runtime.release()
    }

}