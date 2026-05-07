package io.livekit.android.example.voiceassistant

import io.livekit.android.token.TokenRequestOptions

const val tokenEndpoint = "http://10.0.2.2:8787/token"
const val milaAgentName = "mila-agent"
const val milaParticipantName = "Beknazar Android"

fun createTokenRequestOptions(): TokenRequestOptions =
    TokenRequestOptions(
        participantName = milaParticipantName,
        participantMetadata = """{"source":"android","app":"mila-assistant"}""",
        participantAttributes = mapOf(
            "app" to "mila-android",
            "platform" to "android"
        ),
        agentName = milaAgentName,
        agentMetadata = """{"source":"android-app"}"""
    )
