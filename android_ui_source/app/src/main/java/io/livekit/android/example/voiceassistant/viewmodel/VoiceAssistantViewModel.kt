package io.livekit.android.example.voiceassistant.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import io.livekit.android.LiveKit
import io.livekit.android.example.voiceassistant.tokenEndpoint
import io.livekit.android.token.TokenSource
import io.livekit.android.token.cached

/**
 * This ViewModel handles holding onto the Room object, so that it is
 * maintained across configuration changes, such as rotation.
 */
class VoiceAssistantViewModel(application: Application) : AndroidViewModel(application) {

    val room = LiveKit.create(application)

    val tokenSource: TokenSource

    init {
        tokenSource = TokenSource.fromEndpoint(tokenEndpoint).cached()
    }

    override fun onCleared() {
        super.onCleared()
        room.disconnect()
        room.release()
    }
}
