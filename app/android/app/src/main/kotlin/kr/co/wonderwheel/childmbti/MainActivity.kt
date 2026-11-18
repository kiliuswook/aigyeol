package kr.co.wonderwheel.childmbti

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 카카오톡으로 바로 보내기: 공유 창을 거치지 않고 카카오톡의 친구·채팅 고르기 화면을 연다.
        // 카카오 앱 키 없이 동작한다. 카카오톡이 없으면 false 를 돌려주고, 다트 쪽이 공유 창으로 대신한다.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "childmbti/share").setMethodCallHandler { call, result ->
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

    companion object {
        const val KAKAO = "com.kakao.talk"
    }
}
