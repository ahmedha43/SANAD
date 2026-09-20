package com.parentalcontrol.kidsagent.webrtc

import android.content.Context
import android.util.Log
import com.google.gson.Gson
import com.google.gson.JsonElement
import com.parentalcontrol.kidsagent.KidsAgentApp
import org.webrtc.*
import java.net.URI
import java.util.concurrent.Executors

class WebRTCStreamManager(
    private val context: Context,
    private val sendSignalingMessage: (type: String, payload: Any) -> Unit
) {
    companion object {
        private const val TAG = "WebRTCStreamManager"
    }

    private val gson = Gson()
    private val executor = Executors.newSingleThreadExecutor()

    private val rootEglBase: EglBase = EglBase.create()
    private var peerConnectionFactory: PeerConnectionFactory? = null
    private var peerConnection: PeerConnection? = null

    private var surfaceTextureHelper: SurfaceTextureHelper? = null
    private var videoSource: VideoSource? = null
    private var videoCapturer: VideoCapturer? = null
    private var localVideoTrack: VideoTrack? = null

    private var audioSource: AudioSource? = null
    private var localAudioTrack: AudioTrack? = null

    private var hasRemoteDescription = false
    private val pendingIceCandidates = mutableListOf<IceCandidate>()

    init {
        initializePeerConnectionFactory()
    }

    private fun initializePeerConnectionFactory() {
        val initOptions = PeerConnectionFactory.InitializationOptions.builder(context)
            .setEnableInternalTracer(true)
            .createInitializationOptions()
        PeerConnectionFactory.initialize(initOptions)

        val encoderFactory = DefaultVideoEncoderFactory(rootEglBase.eglBaseContext, true, true)
        val decoderFactory = DefaultVideoDecoderFactory(rootEglBase.eglBaseContext)

        peerConnectionFactory = PeerConnectionFactory.builder()
            .setOptions(PeerConnectionFactory.Options())
            .setVideoEncoderFactory(encoderFactory)
            .setVideoDecoderFactory(decoderFactory)
            .createPeerConnectionFactory()
    }

    private fun createCameraCapturer(): VideoCapturer? {
        val enumerator: CameraEnumerator = if (Camera2Enumerator.isSupported(context)) {
            Camera2Enumerator(context)
        } else {
            Camera1Enumerator(true)
        }

        val deviceNames = enumerator.deviceNames
        Log.w(TAG, "Available camera devices: ${deviceNames.joinToString()}")

        val cameraEventsHandler = object : CameraVideoCapturer.CameraEventsHandler {
            override fun onCameraError(errMsg: String?) {
                Log.e(TAG, "Camera error event: $errMsg")
            }
            override fun onCameraDisconnected() {
                Log.w(TAG, "Camera disconnected event")
            }
            override fun onCameraFreezed(errMsg: String?) {
                Log.w(TAG, "Camera freezed event: $errMsg")
            }
            override fun onCameraOpening(cameraName: String?) {
                Log.w(TAG, "Camera opening: $cameraName")
            }
            override fun onFirstFrameAvailable() {
                Log.w(TAG, "CAMERA FIRST FRAME AVAILABLE! Video frames are now streaming!")
            }
            override fun onCameraClosed() {
                Log.w(TAG, "Camera closed event")
            }
        }

        // Prefer back camera, or fallback to front
        for (deviceName in deviceNames) {
            if (enumerator.isBackFacing(deviceName)) {
                val capturer = enumerator.createCapturer(deviceName, cameraEventsHandler)
                if (capturer != null) {
                    Log.w(TAG, "Created back-facing camera capturer: $deviceName")
                    return capturer
                }
            }
        }
        for (deviceName in deviceNames) {
            if (enumerator.isFrontFacing(deviceName)) {
                val capturer = enumerator.createCapturer(deviceName, cameraEventsHandler)
                if (capturer != null) {
                    Log.w(TAG, "Created front-facing camera capturer: $deviceName")
                    return capturer
                }
            }
        }
        return null
    }

    fun handleRemoteOffer(payloadJson: JsonElement) {
        executor.execute {
            try {
                hasRemoteDescription = false
                pendingIceCandidates.clear()

                val rawObj = if (payloadJson.isJsonObject) payloadJson.asJsonObject else return@execute
                val payloadObj = if (rawObj.has("payload") && rawObj.get("payload").isJsonObject) {
                    rawObj.getAsJsonObject("payload")
                } else {
                    rawObj
                }

                val sdpStr = payloadObj.get("sdp")?.asString 
                    ?: rawObj.get("sdp")?.asString 
                    ?: return@execute
                val streamType = payloadObj.get("stream_type")?.asString 
                    ?: rawObj.get("stream_type")?.asString 
                    ?: "camera"
                Log.w(TAG, "Handling remote SDP offer for stream_type: $streamType")

                // Determine server IP for Coturn
                val app = KidsAgentApp.instance
                var serverHost = "192.168.88.54"
                val serverUrl = app.prefs.getString(KidsAgentApp.KEY_SERVER_URL, "") ?: ""
                try {
                    val uri = URI(serverUrl)
                    if (!uri.host.isNullOrEmpty()) {
                        serverHost = uri.host
                    }
                } catch (e: Exception) {
                    // Fallback
                }

                val iceServers = listOf(
                    PeerConnection.IceServer.builder("stun:stun.l.google.com:19302").createIceServer(),
                    PeerConnection.IceServer.builder("stun:$serverHost:3478").createIceServer(),
                    PeerConnection.IceServer.builder("turn:$serverHost:3478")
                        .setUsername("parentalctl")
                        .setPassword("SecureTurnSecretPass2026")
                        .createIceServer()
                )

                val rtcConfig = PeerConnection.RTCConfiguration(iceServers).apply {
                    sdpSemantics = PeerConnection.SdpSemantics.UNIFIED_PLAN
                    continualGatheringPolicy = PeerConnection.ContinualGatheringPolicy.GATHER_CONTINUALLY
                }

                peerConnection?.close()
                peerConnection = peerConnectionFactory?.createPeerConnection(rtcConfig, object : PeerConnection.Observer {
                    override fun onSignalingChange(state: PeerConnection.SignalingState?) {
                        Log.w(TAG, "Signaling State: $state")
                    }
                    override fun onIceConnectionChange(state: PeerConnection.IceConnectionState?) {
                        Log.w(TAG, "ICE Connection State: $state")
                    }
                    override fun onIceConnectionReceivingChange(receiving: Boolean) {}
                    override fun onIceGatheringChange(state: PeerConnection.IceGatheringState?) {
                        Log.w(TAG, "ICE Gathering State: $state")
                    }
                    override fun onIceCandidate(candidate: IceCandidate?) {
                        if (candidate != null) {
                            val candidateMap = mapOf(
                                "sdp" to candidate.sdp,
                                "sdp_mid" to candidate.sdpMid,
                                "sdp_mline_index" to candidate.sdpMLineIndex
                            )
                            sendSignalingMessage("RTC_ICE_CANDIDATE", candidateMap)
                        }
                    }
                    override fun onIceCandidatesRemoved(candidates: Array<out IceCandidate>?) {}
                    override fun onAddStream(stream: MediaStream?) {}
                    override fun onRemoveStream(stream: MediaStream?) {}
                    override fun onDataChannel(channel: DataChannel?) {}
                    override fun onRenegotiationNeeded() {}
                    override fun onAddTrack(receiver: RtpReceiver?, mediaStreams: Array<out MediaStream>?) {
                        val track = receiver?.track()
                        if (track is AudioTrack) {
                            Log.w(TAG, "INCOMING AUDIO TRACK RECEIVED FROM PARENT (Walkie-Talkie)!")
                            track.setEnabled(true)
                            enableLoudspeakerForWalkieTalkie()
                        }
                    }
                })

                // 1. Setup Audio Track
                try {
                    val audioConstraints = MediaConstraints()
                    audioSource = peerConnectionFactory?.createAudioSource(audioConstraints)
                    localAudioTrack = peerConnectionFactory?.createAudioTrack("ARDAMSa0", audioSource)
                    if (localAudioTrack != null) {
                        peerConnection?.addTrack(localAudioTrack, listOf("ARDAMS"))
                        Log.w(TAG, "Added local audio track ARDAMSa0")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to initialize audio track: ${e.message}")
                }

                // 2. Setup Video Track (Camera, Screen, or None for audio-only / ambient / PTT)
                if (streamType == "audio_only" || streamType == "ambient_audio" || streamType == "audio" || streamType == "ptt") {
                    Log.i(TAG, "WebRTC Session initialized in AUDIO-ONLY / AMBIENT mode. No video capturer active.")
                } else if (streamType == "screen") {
                    try {
                        val projectionData = MediaProjectionHolder.projectionIntent
                        if (projectionData != null) {
                            com.parentalcontrol.kidsagent.service.ForegroundSyncService.instance?.ensureMediaProjectionForegroundType()
                            Log.i(TAG, "Starting ScreenCapturerAndroid with stored projection intent...")
                            val screenCapturer = ScreenCapturerAndroid(projectionData, object : android.media.projection.MediaProjection.Callback() {
                                override fun onStop() {
                                    Log.w(TAG, "MediaProjection stopped callback")
                                }
                            })
                            videoCapturer = screenCapturer
                            surfaceTextureHelper = SurfaceTextureHelper.create("ScreenCaptureThread", rootEglBase.eglBaseContext)
                            videoSource = peerConnectionFactory?.createVideoSource(true)
                            videoCapturer?.initialize(surfaceTextureHelper, context, videoSource?.capturerObserver)
                            videoCapturer?.startCapture(720, 1280, 30)

                            localVideoTrack = peerConnectionFactory?.createVideoTrack("ARDAMSv0", videoSource)
                            if (localVideoTrack != null) {
                                peerConnection?.addTrack(localVideoTrack, listOf("ARDAMS"))
                                Log.i(TAG, "Added local SCREEN video track ARDAMSv0")
                            }
                        } else {
                            Log.w(TAG, "MediaProjection not yet granted. Launching ScreenCapturePromptActivity...")
                            val promptIntent = android.content.Intent(context, com.parentalcontrol.kidsagent.ui.ScreenCapturePromptActivity::class.java).apply {
                                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            context.startActivity(promptIntent)
                            sendSignalingMessage("STREAM_ERROR", mapOf(
                                "error" to "يتطلب بث الشاشة موافقة على جهاز الطفل (يظهر طلب الموافقة على الشاشة الآن)",
                                "pending_permission" to true
                            ))
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error initializing screen capturer: ${e.message}")
                        sendSignalingMessage("STREAM_ERROR", mapOf("error" to "خطأ في تشغيل بث الشاشة: ${e.message}"))
                    }
                } else if (streamType == "camera") {
                    try {
                        videoCapturer = createCameraCapturer()
                        if (videoCapturer != null) {
                            surfaceTextureHelper = SurfaceTextureHelper.create("CaptureThread", rootEglBase.eglBaseContext)
                            videoSource = peerConnectionFactory?.createVideoSource(videoCapturer!!.isScreencast)
                            videoCapturer?.initialize(surfaceTextureHelper, context, videoSource?.capturerObserver)
                            videoCapturer?.startCapture(640, 480, 30)

                            localVideoTrack = peerConnectionFactory?.createVideoTrack("ARDAMSv0", videoSource)
                            if (localVideoTrack != null) {
                                peerConnection?.addTrack(localVideoTrack, listOf("ARDAMS"))
                                Log.w(TAG, "Added local video track ARDAMSv0")
                            }
                        } else {
                            Log.e(TAG, "Could not open camera capturer!")
                            sendSignalingMessage("STREAM_ERROR", mapOf("error" to "تعذر فتح كاميرا جهاز الطفل"))
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error initializing camera video capturer: ${e.message}")
                        sendSignalingMessage("STREAM_ERROR", mapOf("error" to "خطأ في تشغيل الكاميرا: ${e.message}"))
                    }
                }

                // 3. Set Remote Description (Offer)
                val sessionDescription = SessionDescription(SessionDescription.Type.OFFER, sdpStr)
                peerConnection?.setRemoteDescription(object : SdpObserver {
                    override fun onSetSuccess() {
                        Log.w(TAG, "Remote description set successfully. Creating Answer...")
                        hasRemoteDescription = true
                        createAnswer()

                        // Flush any queued ICE candidates
                        for (candidate in pendingIceCandidates) {
                            peerConnection?.addIceCandidate(candidate)
                        }
                        pendingIceCandidates.clear()
                    }
                    override fun onSetFailure(err: String?) {
                        Log.e(TAG, "Failed to set remote description: $err")
                    }
                    override fun onCreateSuccess(desc: SessionDescription?) {}
                    override fun onCreateFailure(err: String?) {}
                }, sessionDescription)

            } catch (e: Exception) {
                Log.e(TAG, "Error handling remote offer: ${e.message}")
            }
        }
    }

    private fun createAnswer() {
        val sdpConstraints = MediaConstraints()

        peerConnection?.createAnswer(object : SdpObserver {
            override fun onCreateSuccess(desc: SessionDescription?) {
                if (desc == null) return
                peerConnection?.setLocalDescription(object : SdpObserver {
                    override fun onSetSuccess() {
                        val answerPayload = mapOf("sdp" to desc.description)
                        sendSignalingMessage("RTC_ANSWER", answerPayload)
                        Log.w(TAG, "Local description set and SDP Answer sent.")
                    }
                    override fun onSetFailure(err: String?) {
                        Log.e(TAG, "Failed to set local description: $err")
                    }
                    override fun onCreateSuccess(d: SessionDescription?) {}
                    override fun onCreateFailure(err: String?) {}
                }, desc)
            }
            override fun onCreateFailure(err: String?) {
                Log.e(TAG, "Failed to create answer: $err")
            }
            override fun onSetSuccess() {}
            override fun onSetFailure(err: String?) {}
        }, sdpConstraints)
    }

    fun handleRemoteCandidate(payloadJson: JsonElement) {
        executor.execute {
            try {
                val rawObj = if (payloadJson.isJsonObject) payloadJson.asJsonObject else return@execute
                val obj = if (rawObj.has("payload") && rawObj.get("payload").isJsonObject) {
                    rawObj.getAsJsonObject("payload")
                } else {
                    rawObj
                }

                val sdp = obj.get("sdp")?.asString ?: rawObj.get("sdp")?.asString ?: return@execute
                val sdpMid = obj.get("sdp_mid")?.asString ?: rawObj.get("sdp_mid")?.asString ?: ""
                val sdpMLineIndex = obj.get("sdp_mline_index")?.asInt ?: rawObj.get("sdp_mline_index")?.asInt ?: 0

                val candidate = IceCandidate(sdpMid, sdpMLineIndex, sdp)
                if (hasRemoteDescription && peerConnection != null) {
                    peerConnection?.addIceCandidate(candidate)
                    Log.w(TAG, "Added remote ICE candidate")
                } else {
                    pendingIceCandidates.add(candidate)
                    Log.w(TAG, "Queued remote ICE candidate (waiting for remote description)")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error adding ICE candidate: ${e.message}")
            }
        }
    }

    fun stopStreaming() {
        executor.execute {
            try {
                videoCapturer?.stopCapture()
            } catch (e: Exception) {
                Log.w(TAG, "Error stopping capturer: ${e.message}")
            }
            videoCapturer?.dispose()
            videoCapturer = null

            localVideoTrack?.dispose()
            localVideoTrack = null

            videoSource?.dispose()
            videoSource = null

            surfaceTextureHelper?.dispose()
            surfaceTextureHelper = null

            localAudioTrack?.dispose()
            localAudioTrack = null

            audioSource?.dispose()
            audioSource = null

            peerConnection?.close()
            peerConnection = null

            try {
                val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager
                audioManager?.isSpeakerphoneOn = false
                audioManager?.mode = android.media.AudioManager.MODE_NORMAL
            } catch (e: Exception) {}

            Log.d(TAG, "WebRTC streaming stopped and PeerConnection cleaned up.")
        }
    }

    private fun enableLoudspeakerForWalkieTalkie() {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager
            if (audioManager != null) {
                audioManager.mode = android.media.AudioManager.MODE_IN_COMMUNICATION
                audioManager.isSpeakerphoneOn = true
                val maxVol = audioManager.getStreamMaxVolume(android.media.AudioManager.STREAM_VOICE_CALL)
                audioManager.setStreamVolume(android.media.AudioManager.STREAM_VOICE_CALL, maxVol, 0)
                Log.w(TAG, "Loudspeaker configured for Walkie-Talkie (Volume: $maxVol / Mode: MODE_IN_COMMUNICATION)")

                try {
                    val tone = android.media.ToneGenerator(android.media.AudioManager.STREAM_VOICE_CALL, 90)
                    tone.startTone(android.media.ToneGenerator.TONE_PROP_BEEP2, 180)
                } catch (te: Exception) {}
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error enabling loudspeaker for walkie-talkie: ${e.message}")
        }
    }

    fun switchCamera(callback: ((isFront: Boolean, error: String?) -> Unit)? = null) {
        executor.execute {
            val capturer = videoCapturer as? CameraVideoCapturer
            if (capturer != null) {
                capturer.switchCamera(object : CameraVideoCapturer.CameraSwitchHandler {
                    override fun onCameraSwitchDone(isFrontCamera: Boolean) {
                        Log.i(TAG, "WebRTC camera successfully switched. isFront: $isFrontCamera")
                        callback?.invoke(isFrontCamera, null)
                    }

                    override fun onCameraSwitchError(errorDescription: String?) {
                        Log.e(TAG, "WebRTC camera switch error: $errorDescription")
                        callback?.invoke(false, errorDescription)
                    }
                })
            } else {
                Log.e(TAG, "No active CameraVideoCapturer available to switch")
                callback?.invoke(false, "No active camera capturer")
            }
        }
    }

    fun startScreenCaptureWithIntent(intent: android.content.Intent) {
        executor.execute {
            try {
                if (peerConnection == null || peerConnectionFactory == null) return@execute
                if (videoCapturer != null) return@execute

                Log.i(TAG, "Starting screen capture post-permission grant...")
                com.parentalcontrol.kidsagent.service.ForegroundSyncService.instance?.ensureMediaProjectionForegroundType()
                val screenCapturer = ScreenCapturerAndroid(intent, object : android.media.projection.MediaProjection.Callback() {
                    override fun onStop() {
                        Log.w(TAG, "ScreenCapturerAndroid: MediaProjection stopped")
                    }
                })
                videoCapturer = screenCapturer
                surfaceTextureHelper = SurfaceTextureHelper.create("ScreenCaptureThread", rootEglBase.eglBaseContext)
                videoSource = peerConnectionFactory?.createVideoSource(true)
                videoCapturer?.initialize(surfaceTextureHelper, context, videoSource?.capturerObserver)
                videoCapturer?.startCapture(720, 1280, 30)

                localVideoTrack = peerConnectionFactory?.createVideoTrack("ARDAMSv0", videoSource)
                if (localVideoTrack != null) {
                    peerConnection?.addTrack(localVideoTrack, listOf("ARDAMS"))
                    Log.i(TAG, "Screen video track added post-permission grant!")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start screen capture with new intent: ${e.message}")
            }
        }
    }

    fun dispose() {
        stopStreaming()
        peerConnectionFactory?.dispose()
        peerConnectionFactory = null
        rootEglBase.release()
    }
}
