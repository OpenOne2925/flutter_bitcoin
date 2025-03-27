package cc.cypherpunk.sdk_flutter

import androidx.annotation.NonNull
import com.google.gson.Gson
import com.google.gson.JsonArray
import com.google.gson.JsonObject

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

import kotlinx.coroutines.*
import kotlin.coroutines.*

import uniffi.nfcsdk.CardSdk
import uniffi.nfcsdk.GenerateMnemonicWords

/** SdkFlutterPlugin */
class SdkFlutterPlugin : FlutterPlugin, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private val mainScope = CoroutineScope(Dispatchers.Main)
    private var sdk: CardSdk? = null
    private val gson: Gson = Gson()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "sdk_flutter")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                val useFastMessages: Boolean = call.argument("useFastMessages")!!

                mainScope.launch {
                    try {
                        sdk = CardSdk(useFastMessages)
                        result.success(null)
                    } catch (e: uniffi.nfcsdk.SdkException) {
                        result.error("SDK_EXCEPTION", "Exception from the Rust SDK", e)
                    }
                }
            }
            "poll" -> {
                mainScope.launch {
                    try {
                        val nfcOut = sdk!!.poll()
                        val json = JsonObject().apply {
                            addProperty("msgIndex", nfcOut.msgIndex.toString().toBigInteger())
                            add(
                                "data",
                                gson.toJsonTree(nfcOut.data.map { it.toByte() }.toByteArray())
                            )
                        }
                        result.success(gson.toJson(json))
                    } catch (e: uniffi.nfcsdk.SdkException) {
                        result.error("SDK_EXCEPTION", "Exception from the Rust SDK", e)
                    }
                }
            }
            "ack_send" -> {
                mainScope.launch {
                    try {
                        sdk!!.ackSend()
                        result.success(null)
                    } catch (e: uniffi.nfcsdk.SdkException) {
                        result.error("SDK_EXCEPTION", "Exception from the Rust SDK", e)
                    }
                }
            }
            "incoming_data" -> {
                val msgIndex: Long = call.argument("msgIndex")!!
                val data: ByteArray = call.argument("data")!!

                mainScope.launch {
                    try {
                        sdk!!.incomingData(msgIndex.toULong(), data.map { it.toUByte() })
                        result.success(null)
                    } catch (e: uniffi.nfcsdk.SdkException) {
                        result.error("SDK_EXCEPTION", "Exception from the Rust SDK", e)
                    }
                }
            }
            "new_tag" -> {
                mainScope.launch {
                    try {
                        sdk!!.newTag()
                        result.success(null)
                    } catch (e: uniffi.nfcsdk.SdkException) {
                        result.error("SDK_EXCEPTION", "Exception from the Rust SDK", e)
                    }
                }
            }
            "get_status" -> {
                mainScope.launch {
                    try {
                        val status = sdk!!.getStatus()
                        result.success(gson.toJson(status))
                    } catch (e: uniffi.nfcsdk.SdkException) {
                        result.error("SDK_EXCEPTION", "Exception from the Rust SDK", e)
                    }
                }
            }
            "generate_mnemonic" -> {
                val numWords: String = call.argument("numWords")!!
                val network: String = call.argument("network")!!
                val password = call.argument<String>("password")

                val numWordsParsed = when (numWords) {
                    "GenerateMnemonicWords.Words12" -> GenerateMnemonicWords.WORDS12
                    "GenerateMnemonicWords.Words24" -> GenerateMnemonicWords.WORDS24
                    else -> {
                        result.error("INVALID_NUM_WORDS", "Invalid number of words", null)
                        return
                    }
                }

                mainScope.launch {
                    try {
                        sdk!!.generateMnemonic(numWordsParsed, network, password)
                        result.success(null)
                    } catch (e: uniffi.nfcsdk.SdkException) {
                        result.error("SDK_EXCEPTION", "Exception from the Rust SDK", e)
                    }
                }
            }
            "restore_mnemonic" -> {
                val mnemonic: String = call.argument("mnemonic")!!
                val network: String = call.argument("network")!!
                val password = call.argument<String>("password")

                mainScope.launch {
                    try {
                        sdk!!.restoreMnemonic(mnemonic, network, password)
                        result.success(null)
                    } catch (e: uniffi.nfcsdk.SdkException) {
                        result.error("SDK_EXCEPTION", "Exception from the Rust SDK", e)
                    }
                }
            }
            "unlock" -> {
                val password: String = call.argument("password")!!

                mainScope.launch {
                    try {
                        sdk!!.unlock(password)
                        result.success(null)
                    } catch (e: uniffi.nfcsdk.SdkException) {
                        result.error("SDK_EXCEPTION", "Exception from the Rust SDK", e)
                    }
                }
            }
            "display_address" -> {
                val index: Int = call.argument("index")!!

                mainScope.launch {
                    try {
                        val address = sdk!!.displayAddress(index.toUInt())
                        result.success(address)
                    } catch (e: uniffi.nfcsdk.SdkException) {
                        result.error("SDK_EXCEPTION", "Exception from the Rust SDK", e)
                    }
                }
            }
            "sign_psbt" -> {
                val psbt: String = call.argument("psbt")!!

                mainScope.launch {
                    try {
                        val signed = sdk!!.signPsbt(psbt)
                        result.success(signed)
                    } catch (e: uniffi.nfcsdk.SdkException) {
                        result.error("SDK_EXCEPTION", "Exception from the Rust SDK", e)
                    }
                }
            }
            "public_descriptors" -> {
                mainScope.launch {
                    try {
                        val descriptors = sdk!!.publicDescriptors()
                        val json = JsonObject().apply {
                            addProperty("external", descriptors.external)
                            addProperty("internal", descriptors.internal)
                        }
                        result.success(gson.toJson(json))
                    } catch (e: uniffi.nfcsdk.SdkException) {
                        result.error("SDK_EXCEPTION", "Exception from the Rust SDK", e)
                    }
                }
            }
            "update_firmware" -> {
                val binary: ByteArray = call.argument("binary")!!

                mainScope.launch {
                    try {
                        sdk!!.updateFirmware(binary.map { it.toUByte() })
                        result.success(null)
                    } catch (e: uniffi.nfcsdk.SdkException) {
                        result.error("SDK_EXCEPTION", "Exception from the Rust SDK", e)
                    }
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
