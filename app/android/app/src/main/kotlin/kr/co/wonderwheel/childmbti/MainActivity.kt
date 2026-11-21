package kr.co.wonderwheel.childmbti

import android.content.Intent
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 카카오톡으로 바로 보내기: 공유 창을 거치지 않고 카카오톡의 친구·채팅 고르기 화면을 연다.
        // 카카오 앱 키 없이 동작한다. 카카오톡이 없으면 false 를 돌려주고, 다트 쪽이 공유 창으로 대신한다.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "childmbti/share").setMethodCallHandler { call, result ->
            if (call.method == "referrer") return@setMethodCallHandler readReferrer(result)
            if (call.method != "kakao") return@setMethodCallHandler result.notImplemented()
            val text = call.argument<String>("text") ?: ""
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
                setPackage(KAKAO)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                if (send.resolveActivity(packageManager) == null) return@setMethodCallHandler result.success(false)
                startActivity(send)
                result.success(true)
            } catch (e: Exception) {
                result.success(false)
            }
        }
    }

    /// 구글 플레이 설치 정보: 공유 링크(go/ 페이지)가 플레이 주소의 referrer 에 실어 보낸 값(예: f=ABCDE12345).
    /// 초대 링크로 스토어에서 설치한 사람이 처음 켤 때 초대를 이어 가는 데 쓴다(deeplink.dart). 못 읽으면 null.
    private fun readReferrer(result: MethodChannel.Result) {
        var done = false
        fun reply(v: String?) {
            if (done) return
            done = true
            runOnUiThread { result.success(v) }
        }
        try {
            val client = InstallReferrerClient.newBuilder(this).build()
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(code: Int) {
                    if (code == InstallReferrerClient.InstallReferrerResponse.OK) {
                        val r = try { client.installReferrer.installReferrer } catch (e: Exception) { null }
                        // 플레이가 답을 준 경우 값이 없어도 빈 글자로 돌려준다(다시 묻지 않게)
                        reply(r ?: "")
                    } else if (code == InstallReferrerClient.InstallReferrerResponse.FEATURE_NOT_SUPPORTED) {
                        reply("")
                    } else {
                        reply(null)
                    }
                    try { client.endConnection() } catch (_: Exception) {}
                }
                override fun onInstallReferrerServiceDisconnected() = reply(null)
            })
        } catch (e: Exception) {
            reply(null)
        }
    }

    companion object {
        const val KAKAO = "com.kakao.talk"
    }
}
