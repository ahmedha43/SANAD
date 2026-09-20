/**
 * WebRTC Live Camera Controller
 * Manages browser-side RTCPeerConnection for live camera streaming
 */

const WebRTCController = {
    _pc: null,
    _isStreaming: false,

    async start() {
        if (this._isStreaming) return;
        document.getElementById('streamBadge').textContent = 'جاري الاتصال...';
        document.getElementById('streamBadge').className = 'stream-badge-status connecting';

        try {
            const config = await API.getWebRTCConfig();
            const iceServers = [];
            if (config.stun_url) iceServers.push({ urls: config.stun_url });
            if (config.turn_url) {
                iceServers.push({
                    urls: config.turn_url,
                    username: config.turn_username || 'parentalctl',
                    credential: config.turn_credential || ''
                });
            }

            this._pc = new RTCPeerConnection({ iceServers });

            this._pc.ontrack = (event) => {
                const video = document.getElementById('remoteVideo');
                video.srcObject = event.streams[0];
                document.getElementById('videoPlaceholder').style.display = 'none';
                document.getElementById('streamControlsOverlay').style.display = 'flex';
                document.getElementById('streamBadge').textContent = '● LIVE';
                document.getElementById('streamBadge').className = 'stream-badge-status live';
                this._isStreaming = true;
            };

            this._pc.onicecandidate = (event) => {
                if (event.candidate) {
                    WS.send('RTC_ICE_CANDIDATE', {
                        sdp: event.candidate.candidate,
                        sdp_mid: event.candidate.sdpMid,
                        sdp_mline_index: event.candidate.sdpMLineIndex,
                        candidate: event.candidate
                    }, window.STATE?.activeDeviceId);
                }
            };

            this._pc.onconnectionstatechange = () => {
                if (['disconnected', 'failed', 'closed'].includes(this._pc.connectionState)) {
                    this.stop();
                }
            };

            // Add transceiver to receive video
            this._pc.addTransceiver('video', { direction: 'recvonly' });
            this._pc.addTransceiver('audio', { direction: 'recvonly' });

            const offer = await this._pc.createOffer();
            await this._pc.setLocalDescription(offer);

            WS.send('RTC_OFFER', {
                sdp: offer.sdp,
                type: offer.type,
                stream_type: 'camera'
            }, window.STATE?.activeDeviceId);

        } catch (err) {
            console.error('[WebRTC] Start failed:', err);
            UI.showToast('فشل بدء البث المباشر: ' + err.message, 'error');
            document.getElementById('streamBadge').textContent = 'خطأ في الاتصال';
            document.getElementById('streamBadge').className = 'stream-badge-status error';
        }
    },

    async handleSignaling(msg) {
        if (!this._pc) return;
        const payload = msg.payload || msg;
        if (msg.type === 'RTC_ANSWER') {
            const sdp = payload.sdp || (typeof payload === 'string' ? payload : null);
            if (sdp) {
                await this._pc.setRemoteDescription(new RTCSessionDescription({ type: 'answer', sdp: sdp }));
                console.log('[WebRTC] Remote description (answer) set successfully');
            }
        } else if (msg.type === 'RTC_ICE_CANDIDATE') {
            try {
                if (payload.candidate && typeof payload.candidate === 'object') {
                    await this._pc.addIceCandidate(new RTCIceCandidate(payload.candidate));
                } else {
                    const candStr = payload.sdp || payload.candidate;
                    if (candStr) {
                        await this._pc.addIceCandidate(new RTCIceCandidate({
                            candidate: candStr,
                            sdpMid: payload.sdp_mid || payload.sdpMid || '0',
                            sdpMLineIndex: payload.sdp_mline_index ?? payload.sdpMLineIndex ?? 0
                        }));
                    }
                }
            } catch (candErr) {
                console.warn('[WebRTC] Error adding remote candidate:', candErr);
            }
        }
    },

    switchCamera() {
        WS.send('CAMERA_SWITCH', {}, window.STATE?.activeDeviceId);
        UI.showToast('تم إرسال أمر تبديل الكاميرا', 'info');
    },

    stop() {
        if (this._pc) { this._pc.close(); this._pc = null; }
        this._isStreaming = false;
        const video = document.getElementById('remoteVideo');
        if (video) { video.srcObject = null; }
        const placeholder = document.getElementById('videoPlaceholder');
        if (placeholder) placeholder.style.display = 'flex';
        const overlay = document.getElementById('streamControlsOverlay');
        if (overlay) overlay.style.display = 'none';
        const badge = document.getElementById('streamBadge');
        if (badge) { badge.textContent = 'جاهز للبث'; badge.className = 'stream-badge-status'; }
        WS.send('STREAM_STOP', {}, window.STATE?.activeDeviceId);
    }
};

// Global bridge functions called from PHP views
function startLiveCameraStream() { WebRTCController.start(); }
function stopLiveCameraStream() { WebRTCController.stop(); }
function switchCameraFacing() { WebRTCController.switchCamera(); }

window.WebRTCController = WebRTCController;

/**
 * ScreenStreamController - WebRTC Live Screen Mirroring & Continuous Silent Surveillance
 */
const ScreenStreamController = {
    _pc: null,
    _isStreaming: false,
    _streamType: 'screen',
    _silentTimer: null,
    _silentInterval: 5000,
    isSurveillanceActive: false,
    _lastSnapshotBase64: null,

    async startWebRTC() {
        if (this._isStreaming) return;
        const badge = document.getElementById('screenStreamBadge');
        if (badge) {
            badge.textContent = 'جاري الاتصال...';
            badge.className = 'stream-badge-status connecting';
        }
        const note = document.getElementById('screenStreamNote');
        if (note) note.textContent = 'جاري طلب الاتصال بشاشة جهاز الطفل...';

        try {
            const config = await API.getWebRTCConfig();
            const iceServers = [];
            if (config.stun_url) iceServers.push({ urls: config.stun_url });
            if (config.turn_url) {
                iceServers.push({
                    urls: config.turn_url,
                    username: config.turn_username || 'parentalctl',
                    credential: config.turn_credential || ''
                });
            }

            this._pc = new RTCPeerConnection({ iceServers });

            this._pc.ontrack = (event) => {
                const video = document.getElementById('remoteScreenVideo');
                if (video) {
                    video.srcObject = event.streams[0];
                    video.style.display = 'block';
                }
                const placeholder = document.getElementById('screenVideoPlaceholder');
                if (placeholder) placeholder.style.display = 'none';
                const overlay = document.getElementById('screenControlsOverlay');
                if (overlay) overlay.style.display = 'flex';
                if (badge) {
                    badge.textContent = '● LIVE SCREEN';
                    badge.className = 'stream-badge-status live';
                }
                this._isStreaming = true;
            };

            this._pc.onicecandidate = (event) => {
                if (event.candidate) {
                    WS.send('RTC_ICE_CANDIDATE', {
                        sdp: event.candidate.candidate,
                        sdp_mid: event.candidate.sdpMid,
                        sdp_mline_index: event.candidate.sdpMLineIndex,
                        candidate: event.candidate
                    }, window.STATE?.activeDeviceId);
                }
            };

            this._pc.onconnectionstatechange = () => {
                if (['disconnected', 'failed', 'closed'].includes(this._pc.connectionState)) {
                    this.stopWebRTC();
                }
            };

            this._pc.addTransceiver('video', { direction: 'recvonly' });
            this._pc.addTransceiver('audio', { direction: 'recvonly' });

            const offer = await this._pc.createOffer();
            await this._pc.setLocalDescription(offer);

            WS.send('RTC_OFFER', {
                sdp: offer.sdp,
                type: offer.type,
                stream_type: 'screen'
            }, window.STATE?.activeDeviceId);

        } catch (err) {
            console.error('[ScreenWebRTC] Start failed:', err);
            UI.showToast('فشل بدء بث الشاشة: ' + err.message, 'error');
            if (badge) {
                badge.textContent = 'خطأ في الاتصال';
                badge.className = 'stream-badge-status error';
            }
        }
    },

    async handleSignaling(msg) {
        const payload = msg.payload || msg;
        if (msg.type === 'STREAM_ERROR') {
            const err = payload.error || 'خطأ في بث الشاشة';
            UI.showToast(err, 'warning');
            const badge = document.getElementById('screenStreamBadge');
            if (badge) {
                badge.textContent = 'في انتظار إذن الشاشة';
                badge.className = 'stream-badge-status warning';
            }
            const note = document.getElementById('screenStreamNote');
            if (note) {
                note.innerHTML = `<span style="color:#f59e0b; font-weight:bold;">⚠️ ${err}</span>`;
            }
            return;
        }

        if (!this._pc) return;

        if (msg.type === 'RTC_ANSWER') {
            const sdp = payload.sdp || (typeof payload === 'string' ? payload : null);
            if (sdp) {
                await this._pc.setRemoteDescription(new RTCSessionDescription({ type: 'answer', sdp: sdp }));
                console.log('[ScreenWebRTC] Remote description (answer) set successfully');
            }
        } else if (msg.type === 'RTC_ICE_CANDIDATE') {
            try {
                if (payload.candidate && typeof payload.candidate === 'object') {
                    await this._pc.addIceCandidate(new RTCIceCandidate(payload.candidate));
                } else {
                    const candStr = payload.sdp || payload.candidate;
                    if (candStr) {
                        await this._pc.addIceCandidate(new RTCIceCandidate({
                            candidate: candStr,
                            sdpMid: payload.sdp_mid || payload.sdpMid || '0',
                            sdpMLineIndex: payload.sdp_mline_index ?? payload.sdpMLineIndex ?? 0
                        }));
                    }
                }
            } catch (candErr) {
                console.warn('[ScreenWebRTC] Error adding remote candidate:', candErr);
            }
        }
    },

    stopWebRTC() {
        if (this._pc) { this._pc.close(); this._pc = null; }
        this._isStreaming = false;
        const video = document.getElementById('remoteScreenVideo');
        if (video) {
            video.srcObject = null;
            video.style.display = 'none';
        }
        const placeholder = document.getElementById('screenVideoPlaceholder');
        if (placeholder) placeholder.style.display = 'flex';
        const overlay = document.getElementById('screenControlsOverlay');
        if (overlay) overlay.style.display = 'none';
        const badge = document.getElementById('screenStreamBadge');
        if (badge) { badge.textContent = 'جاهز للبث'; badge.className = 'stream-badge-status'; }
        
        WS.send('STREAM_STOP', {}, window.STATE?.activeDeviceId);
    },

    // Silent Periodic Surveillance
    startSilentSurveillance() {
        this.isSurveillanceActive = true;
        const icon = document.getElementById('silentSurveillanceIcon');
        const text = document.getElementById('silentSurveillanceText');
        const btn = document.getElementById('btnToggleSilentSurveillance');
        const status = document.getElementById('silentStatusText');
        const badge = document.getElementById('screenStreamBadge');

        if (icon) icon.className = 'fa-solid fa-stop';
        if (text) text.textContent = 'إيقاف التحديث الدوري';
        if (btn) btn.style.background = '#ef4444';
        if (status) status.textContent = `التحديث الدوري نشط (كل ${this._silentInterval / 1000} ثوانٍ)`;
        if (badge) {
            badge.textContent = '● تحديث دوري';
            badge.className = 'stream-badge-status live';
        }

        // Trigger immediate capture
        this.requestSnapshot();

        // Start interval
        if (this._silentTimer) clearInterval(this._silentTimer);
        this._silentTimer = setInterval(() => {
            if (this.isSurveillanceActive) {
                this.requestSnapshot();
            }
        }, this._silentInterval);
    },

    stopSilentSurveillance() {
        this.isSurveillanceActive = false;
        if (this._silentTimer) {
            clearInterval(this._silentTimer);
            this._silentTimer = null;
        }
        const icon = document.getElementById('silentSurveillanceIcon');
        const text = document.getElementById('silentSurveillanceText');
        const btn = document.getElementById('btnToggleSilentSurveillance');
        const status = document.getElementById('silentStatusText');
        const badge = document.getElementById('screenStreamBadge');

        if (icon) icon.className = 'fa-solid fa-play';
        if (text) text.textContent = 'بدء التحديث الدوري المستمر';
        if (btn) btn.style.background = '#10b981';
        if (status) status.textContent = 'التحديث الدوري متوقف';
        if (badge) {
            badge.textContent = 'جاهز';
            badge.className = 'stream-badge-status';
        }
    },

    requestSnapshot() {
        if (!window.STATE?.activeDeviceId) return;
        const spinner = document.getElementById('silentSurveillanceSpinner');
        if (spinner && !this._lastSnapshotBase64) spinner.style.display = 'block';

        if (window.WS && typeof window.WS.send === 'function') {
            window.WS.send('TAKE_SCREENSHOT', {}, window.STATE.activeDeviceId);
        }
        if (typeof sendCommand === 'function') {
            sendCommand('TAKE_SCREENSHOT');
        }
    },

    handleIncomingSnapshot(payload) {
        const spinner = document.getElementById('silentSurveillanceSpinner');
        if (spinner) spinner.style.display = 'none';

        if (payload.error) {
            console.warn('[Surveillance] Snapshot error:', payload.error);
            return;
        }

        const b64 = payload.image_base64;
        if (!b64) return;

        this._lastSnapshotBase64 = b64;
        const img = document.getElementById('silentSurveillanceImg');
        const placeholder = document.getElementById('silentSurveillancePlaceholder');
        const tsOverlay = document.getElementById('silentTimestampOverlay');
        const tsText = document.getElementById('silentLastUpdatedTime');
        const dlBtn = document.getElementById('btnDownloadSilentSnapshot');

        if (img) {
            img.src = b64.startsWith('data:') ? b64 : `data:image/jpeg;base64,${b64}`;
            img.style.display = 'block';
        }
        if (placeholder) placeholder.style.display = 'none';
        if (tsOverlay) tsOverlay.style.display = 'flex';
        if (dlBtn) dlBtn.style.display = 'inline-flex';
        if (tsText) {
            const now = new Date();
            tsText.textContent = `آخر تحديث: ${now.toLocaleTimeString('ar-SA')}`;
        }
    }
};

// Global Bridge Functions for Screen Mirroring
function startLiveScreenStream() {
    ScreenStreamController.startWebRTC();
}

function stopLiveScreenStream() {
    ScreenStreamController.stopWebRTC();
}

function switchScreenSubMode(mode) {
    const tabWebRTC = document.getElementById('tabScreenWebRTC');
    const tabSilent = document.getElementById('tabScreenSilent');
    const viewWebRTC = document.getElementById('screenWebRTCContainer');
    const viewSilent = document.getElementById('screenSilentContainer');

    if (mode === 'webrtc') {
        if (tabWebRTC) { tabWebRTC.style.background = '#6366f1'; tabWebRTC.style.color = '#fff'; }
        if (tabSilent) { tabSilent.style.background = 'transparent'; tabSilent.style.color = 'var(--text-muted)'; }
        if (viewWebRTC) viewWebRTC.style.display = 'block';
        if (viewSilent) viewSilent.style.display = 'none';
    } else {
        if (tabSilent) { tabSilent.style.background = '#10b981'; tabSilent.style.color = '#fff'; }
        if (tabWebRTC) { tabWebRTC.style.background = 'transparent'; tabWebRTC.style.color = 'var(--text-muted)'; }
        if (viewWebRTC) viewWebRTC.style.display = 'none';
        if (viewSilent) viewSilent.style.display = 'block';
    }
}

function toggleScreenAudio() {
    const video = document.getElementById('remoteScreenVideo');
    const icon = document.getElementById('screenAudioIcon');
    if (!video) return;
    video.muted = !video.muted;
    if (icon) {
        icon.className = video.muted ? 'fa-solid fa-volume-xmark' : 'fa-solid fa-volume-high';
    }
    UI.showToast(video.muted ? 'تم كتم الصوت' : 'تم تشغيل الصوت', 'info');
}

function toggleScreenFullscreen() {
    const frame = document.getElementById('phoneMirrorFrame');
    if (!frame) return;
    if (!document.fullscreenElement) {
        frame.requestFullscreen?.().catch(err => console.warn(err));
    } else {
        document.exitFullscreen?.().catch(err => console.warn(err));
    }
}

function toggleSilentSurveillance() {
    if (ScreenStreamController.isSurveillanceActive) {
        ScreenStreamController.stopSilentSurveillance();
    } else {
        ScreenStreamController.startSilentSurveillance();
    }
}

function captureSingleSnapshotNow() {
    UI.showToast('جاري التقاط لقطة فورية...', 'info');
    ScreenStreamController.requestSnapshot();
}

function changeSilentInterval(val) {
    ScreenStreamController._silentInterval = parseInt(val, 10) || 5000;
    if (ScreenStreamController.isSurveillanceActive) {
        ScreenStreamController.stopSilentSurveillance();
        ScreenStreamController.startSilentSurveillance();
    }
    UI.showToast(`تم ضبط معدل التحديث إلى ${ScreenStreamController._silentInterval / 1000} ثوانٍ`, 'info');
}

function downloadCurrentSnapshot() {
    if (!ScreenStreamController._lastSnapshotBase64) return;
    const link = document.createElement('a');
    link.download = `child_screen_${Date.now()}.jpg`;
    link.href = ScreenStreamController._lastSnapshotBase64.startsWith('data:') 
        ? ScreenStreamController._lastSnapshotBase64 
        : `data:image/jpeg;base64,${ScreenStreamController._lastSnapshotBase64}`;
    link.click();
}

function toggleSilentFullscreen() {
    const frame = document.getElementById('silentPhoneFrame');
    if (!frame) return;
    if (!document.fullscreenElement) {
        frame.requestFullscreen?.().catch(err => console.warn(err));
    } else {
        document.exitFullscreen?.().catch(err => console.warn(err));
    }
}

window.ScreenStreamController = ScreenStreamController;
window.startLiveScreenStream = startLiveScreenStream;
window.stopLiveScreenStream = stopLiveScreenStream;
window.switchScreenSubMode = switchScreenSubMode;
window.toggleScreenAudio = toggleScreenAudio;
window.toggleScreenFullscreen = toggleScreenFullscreen;
window.toggleSilentSurveillance = toggleSilentSurveillance;
window.captureSingleSnapshotNow = captureSingleSnapshotNow;
window.changeSilentInterval = changeSilentInterval;
window.downloadCurrentSnapshot = downloadCurrentSnapshot;
window.toggleSilentFullscreen = toggleSilentFullscreen;


/**
 * AmbientAudioController - Remote WebRTC Audio-Only Surveillance
 */
const AmbientAudioController = {
    _pc: null,
    _isListening: false,
    _timerInterval: null,
    _secondsElapsed: 0,

    async start() {
        if (this._isListening) return;
        const badge = document.getElementById('ambientBadge');
        if (badge) {
            badge.textContent = 'جاري الاتصال بالميكروفون...';
            badge.className = 'stream-badge-status connecting';
        }

        try {
            const config = await API.getWebRTCConfig();
            const iceServers = [];
            if (config.stun_url) iceServers.push({ urls: config.stun_url });
            if (config.turn_url) {
                iceServers.push({
                    urls: config.turn_url,
                    username: config.turn_username || 'parentalctl',
                    credential: config.turn_credential || ''
                });
            }

            this._pc = new RTCPeerConnection({ iceServers });

            this._pc.ontrack = (event) => {
                const player = document.getElementById('ambientAudioPlayer');
                if (player) {
                    player.srcObject = event.streams[0];
                    player.play().catch(e => console.warn('[AmbientAudio] Play autoplay blocked:', e));
                }

                // UI indicators
                const bars = document.getElementById('ambientAudioBars');
                const avatar = document.getElementById('ambientMicAvatar');
                const timerWrap = document.getElementById('ambientTimerWrap');
                const btnText = document.getElementById('ambientBtnText');
                const btnIcon = document.getElementById('ambientBtnIcon');
                const btnToggle = document.getElementById('btnToggleAmbientAudio');

                if (bars) bars.style.display = 'inline-flex';
                if (avatar) avatar.classList.add('active-pulsing');
                if (timerWrap) timerWrap.style.display = 'block';
                if (btnText) btnText.textContent = 'إنهاء الاستماع للمحيط';
                if (btnIcon) btnIcon.className = 'fa-solid fa-stop';
                if (btnToggle) btnToggle.style.background = 'linear-gradient(135deg, #b91c1c, #ef4444)';

                if (badge) {
                    badge.textContent = '● استماع حي مباشر';
                    badge.className = 'stream-badge-status live';
                }

                this._startTimer();
                this._isListening = true;
                UI.showToast('تم بدء الاستماع للمحيط بنجاح', 'success');
            };

            this._pc.onicecandidate = (event) => {
                if (event.candidate) {
                    WS.send('RTC_ICE_CANDIDATE', {
                        sdp: event.candidate.candidate,
                        sdp_mid: event.candidate.sdpMid,
                        sdp_mline_index: event.candidate.sdpMLineIndex,
                        candidate: event.candidate
                    }, window.STATE?.activeDeviceId);
                }
            };

            this._pc.onconnectionstatechange = () => {
                if (['disconnected', 'failed', 'closed'].includes(this._pc?.connectionState)) {
                    this.stop();
                }
            };

            // Audio-only transceiver (NO video transceiver)
            this._pc.addTransceiver('audio', { direction: 'recvonly' });

            const offer = await this._pc.createOffer();
            await this._pc.setLocalDescription(offer);

            WS.send('RTC_OFFER', {
                sdp: offer.sdp,
                type: offer.type,
                stream_type: 'audio_only'
            }, window.STATE?.activeDeviceId);

        } catch (err) {
            console.error('[AmbientAudio] Start failed:', err);
            UI.showToast('فشل بدء الاستماع للمحيط: ' + err.message, 'error');
            if (badge) {
                badge.textContent = 'خطأ في الاتصال';
                badge.className = 'stream-badge-status error';
            }
        }
    },

    stop() {
        if (this._pc) {
            this._pc.close();
            this._pc = null;
        }
        this._isListening = false;
        this._stopTimer();

        const player = document.getElementById('ambientAudioPlayer');
        if (player) {
            player.pause();
            player.srcObject = null;
        }

        const bars = document.getElementById('ambientAudioBars');
        const avatar = document.getElementById('ambientMicAvatar');
        const timerWrap = document.getElementById('ambientTimerWrap');
        const btnText = document.getElementById('ambientBtnText');
        const btnIcon = document.getElementById('ambientBtnIcon');
        const btnToggle = document.getElementById('btnToggleAmbientAudio');
        const badge = document.getElementById('ambientBadge');

        if (bars) bars.style.display = 'none';
        if (avatar) avatar.classList.remove('active-pulsing');
        if (timerWrap) timerWrap.style.display = 'none';
        if (btnText) btnText.textContent = 'بدء الاستماع للمحيط الآن';
        if (btnIcon) btnIcon.className = 'fa-solid fa-headphones';
        if (btnToggle) btnToggle.style.background = 'linear-gradient(135deg, #059669, #10b981)';
        if (badge) {
            badge.textContent = 'جاهز للاستماع';
            badge.className = 'stream-badge-status';
        }

        WS.send('STREAM_STOP', {}, window.STATE?.activeDeviceId);
    },

    _startTimer() {
        this._secondsElapsed = 0;
        this._stopTimer();
        const durationEl = document.getElementById('ambientDuration');
        this._timerInterval = setInterval(() => {
            this._secondsElapsed++;
            const mins = String(Math.floor(this._secondsElapsed / 60)).padStart(2, '0');
            const secs = String(this._secondsElapsed % 60).padStart(2, '0');
            if (durationEl) durationEl.textContent = `${mins}:${secs}`;
        }, 1000);
    },

    _stopTimer() {
        if (this._timerInterval) {
            clearInterval(this._timerInterval);
            this._timerInterval = null;
        }
    },

    async handleSignaling(msg) {
        if (!this._pc) return;
        const payload = msg.payload || msg;
        if (msg.type === 'RTC_ANSWER') {
            const sdp = payload.sdp || (typeof payload === 'string' ? payload : null);
            if (sdp) {
                await this._pc.setRemoteDescription(new RTCSessionDescription({ type: 'answer', sdp: sdp }));
                console.log('[AmbientAudio] Remote description set');
            }
        } else if (msg.type === 'RTC_ICE_CANDIDATE') {
            try {
                if (payload.candidate && typeof payload.candidate === 'object') {
                    await this._pc.addIceCandidate(new RTCIceCandidate(payload.candidate));
                } else {
                    const candStr = payload.sdp || payload.candidate;
                    if (candStr) {
                        await this._pc.addIceCandidate(new RTCIceCandidate({
                            candidate: candStr,
                            sdpMid: payload.sdp_mid || payload.sdpMid || '0',
                            sdpMLineIndex: payload.sdp_mline_index ?? payload.sdpMLineIndex ?? 0
                        }));
                    }
                }
            } catch (candErr) {
                console.warn('[AmbientAudio] Candidate error:', candErr);
            }
        }
    }
};

/**
 * WalkieTalkieController - Instant Push-to-Talk (Loudspeaker Bypass Silent Mode)
 */
const WalkieTalkieController = {
    _pc: null,
    _localStream: null,
    _isTransmitting: false,
    _isContinuous: false,
    _audioCtx: null,
    _animFrame: null,

    playChirpTone(freqStart = 700, freqEnd = 1200, duration = 0.12) {
        try {
            const ctx = new (window.AudioContext || window.webkitAudioContext)();
            const osc = ctx.createOscillator();
            const gain = ctx.createGain();
            osc.connect(gain);
            gain.connect(ctx.destination);
            osc.type = 'sine';
            osc.frequency.setValueAtTime(freqStart, ctx.currentTime);
            osc.frequency.exponentialRampToValueAtTime(freqEnd, ctx.currentTime + duration);
            gain.gain.setValueAtTime(0.3, ctx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + duration);
            osc.start();
            osc.stop(ctx.currentTime + duration);
        } catch (e) {}
    },

    async start() {
        if (this._isTransmitting) return;
        this._isTransmitting = true;

        const badge = document.getElementById('pttBadge');
        const pttBtn = document.getElementById('pttButton');
        const pttText = document.getElementById('pttText');
        const vuMeter = document.getElementById('pttVuMeter');

        if (badge) {
            badge.textContent = '🎙️ جاري التحدث (مكبر الصوت نشط)';
            badge.className = 'stream-badge-status live';
        }
        if (pttBtn) pttBtn.classList.add('transmitting');
        if (pttText) pttText.textContent = 'يتم البث الآن...';
        if (vuMeter) vuMeter.style.display = 'block';

        this.playChirpTone(700, 1400, 0.15);

        try {
            // Get parent microphone
            this._localStream = await navigator.mediaDevices.getUserMedia({
                audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
                video: false
            });

            // Start AudioContext VU Meter
            this._startVuMeter(this._localStream);

            // Inform child agent of PTT Start
            WS.send('PTT_START', {}, window.STATE?.activeDeviceId);

            const config = await API.getWebRTCConfig();
            const iceServers = [];
            if (config.stun_url) iceServers.push({ urls: config.stun_url });
            if (config.turn_url) {
                iceServers.push({
                    urls: config.turn_url,
                    username: config.turn_username || 'parentalctl',
                    credential: config.turn_credential || ''
                });
            }

            this._pc = new RTCPeerConnection({ iceServers });

            this._localStream.getTracks().forEach(track => {
                this._pc.addTrack(track, this._localStream);
            });

            this._pc.onicecandidate = (event) => {
                if (event.candidate) {
                    WS.send('RTC_ICE_CANDIDATE', {
                        sdp: event.candidate.candidate,
                        sdp_mid: event.candidate.sdpMid,
                        sdp_mline_index: event.candidate.sdpMLineIndex,
                        candidate: event.candidate
                    }, window.STATE?.activeDeviceId);
                }
            };

            this._pc.onconnectionstatechange = () => {
                if (['disconnected', 'failed', 'closed'].includes(this._pc?.connectionState)) {
                    this.stop();
                }
            };

            const offer = await this._pc.createOffer();
            await this._pc.setLocalDescription(offer);

            WS.send('RTC_OFFER', {
                sdp: offer.sdp,
                type: offer.type,
                stream_type: 'ptt'
            }, window.STATE?.activeDeviceId);

        } catch (err) {
            console.error('[WalkieTalkie] Mic error:', err);
            UI.showToast('تعذر الوصول إلى الميكروفون: ' + err.message, 'error');
            this.stop();
        }
    },

    stop() {
        if (!this._isTransmitting) return;
        this._isTransmitting = false;

        this.playChirpTone(1200, 600, 0.1);

        if (this._localStream) {
            this._localStream.getTracks().forEach(t => t.stop());
            this._localStream = null;
        }

        if (this._pc) {
            this._pc.close();
            this._pc = null;
        }

        this._stopVuMeter();

        const badge = document.getElementById('pttBadge');
        const pttBtn = document.getElementById('pttButton');
        const pttText = document.getElementById('pttText');
        const vuMeter = document.getElementById('pttVuMeter');

        if (badge) {
            badge.textContent = 'جاهز للإرسال';
            badge.className = 'stream-badge-status';
        }
        if (pttBtn) pttBtn.classList.remove('transmitting');
        if (pttText) pttText.textContent = 'اضغط وتحدث';
        if (vuMeter) vuMeter.style.display = 'none';

        WS.send('PTT_STOP', {}, window.STATE?.activeDeviceId);
        WS.send('STREAM_STOP', {}, window.STATE?.activeDeviceId);
    },

    _startVuMeter(stream) {
        try {
            this._audioCtx = new (window.AudioContext || window.webkitAudioContext)();
            const source = this._audioCtx.createMediaStreamSource(stream);
            const analyser = this._audioCtx.createAnalyser();
            analyser.fftSize = 64;
            source.connect(analyser);

            const dataArray = new Uint8Array(analyser.frequencyBinCount);
            const bar = document.getElementById('pttVolumeBar');
            const percent = document.getElementById('pttVolumePercent');

            const draw = () => {
                if (!this._isTransmitting) return;
                analyser.getByteFrequencyData(dataArray);
                let sum = 0;
                for (let i = 0; i < dataArray.length; i++) {
                    sum += dataArray[i];
                }
                const avg = Math.min(100, Math.round((sum / dataArray.length) * 1.5));
                if (bar) bar.style.width = avg + '%';
                if (percent) percent.textContent = avg + '%';
                this._animFrame = requestAnimationFrame(draw);
            };
            draw();
        } catch (e) {}
    },

    _stopVuMeter() {
        if (this._animFrame) {
            cancelAnimationFrame(this._animFrame);
            this._animFrame = null;
        }
        if (this._audioCtx) {
            try { this._audioCtx.close(); } catch(e) {}
            this._audioCtx = null;
        }
        const bar = document.getElementById('pttVolumeBar');
        const percent = document.getElementById('pttVolumePercent');
        if (bar) bar.style.width = '0%';
        if (percent) percent.textContent = '0%';
    },

    toggleContinuous() {
        this._isContinuous = !this._isContinuous;
        const icon = document.getElementById('pttToggleIcon');
        const text = document.getElementById('pttToggleText');
        const btn = document.getElementById('btnPttToggleMode');

        if (this._isContinuous) {
            if (icon) icon.className = 'fa-solid fa-toggle-on';
            if (text) text.textContent = 'إيقاف التحدث المستمر';
            if (btn) btn.classList.add('btn-primary');
            this.start();
        } else {
            if (icon) icon.className = 'fa-solid fa-toggle-off';
            if (text) text.textContent = 'تحدث حر مستمر';
            if (btn) btn.classList.remove('btn-primary');
            this.stop();
        }
    },

    async handleSignaling(msg) {
        if (!this._pc) return;
        const payload = msg.payload || msg;
        if (msg.type === 'RTC_ANSWER') {
            const sdp = payload.sdp || (typeof payload === 'string' ? payload : null);
            if (sdp) {
                await this._pc.setRemoteDescription(new RTCSessionDescription({ type: 'answer', sdp: sdp }));
                console.log('[WalkieTalkie] Remote answer set');
            }
        } else if (msg.type === 'RTC_ICE_CANDIDATE') {
            try {
                if (payload.candidate && typeof payload.candidate === 'object') {
                    await this._pc.addIceCandidate(new RTCIceCandidate(payload.candidate));
                } else {
                    const candStr = payload.sdp || payload.candidate;
                    if (candStr) {
                        await this._pc.addIceCandidate(new RTCIceCandidate({
                            candidate: candStr,
                            sdpMid: payload.sdp_mid || payload.sdpMid || '0',
                            sdpMLineIndex: payload.sdp_mline_index ?? payload.sdpMLineIndex ?? 0
                        }));
                    }
                }
            } catch (candErr) {
                console.warn('[WalkieTalkie] Candidate error:', candErr);
            }
        }
    }
};

// Global Bridge Functions
function toggleAmbientAudioStream() {
    if (AmbientAudioController._isListening) {
        AmbientAudioController.stop();
    } else {
        AmbientAudioController.start();
    }
}

function setAmbientVolume(val) {
    const player = document.getElementById('ambientAudioPlayer');
    const valText = document.getElementById('ambientVolVal');
    const vol = (parseInt(val, 10) || 0) / 100;
    if (player) player.volume = vol;
    if (valText) valText.textContent = val + '%';
}

function toggleAmbientMute() {
    const player = document.getElementById('ambientAudioPlayer');
    const icon = document.getElementById('ambientVolIcon');
    if (!player) return;
    player.muted = !player.muted;
    if (icon) {
        icon.className = player.muted ? 'fa-solid fa-volume-xmark' : 'fa-solid fa-volume-high';
    }
    UI.showToast(player.muted ? 'تم كتم الصوت' : 'تم تفعيل الصوت', 'info');
}

function startPushToTalk(e) {
    if (e && e.preventDefault) e.preventDefault();
    if (!WalkieTalkieController._isContinuous) {
        WalkieTalkieController.start();
    }
}

function stopPushToTalk(e) {
    if (e && e.preventDefault) e.preventDefault();
    if (!WalkieTalkieController._isContinuous) {
        WalkieTalkieController.stop();
    }
}

function toggleContinuousTalk() {
    WalkieTalkieController.toggleContinuous();
}

function requestDeviceOwnerStatus() {
    UI.showToast('جاري الاستعلام عن حالة Device Owner...', 'info');
    WS.send('GET_DEVICE_OWNER_STATUS', {}, window.STATE?.activeDeviceId);
}

function openDeviceOwnerModal() {
    const modal = document.getElementById('deviceOwnerModal');
    if (modal) modal.style.display = 'flex';
}

function copyAdbCommand() {
    const cmd = document.getElementById('adbCommandText');
    const btnText = document.getElementById('copyAdbBtnText');
    if (!cmd) return;
    navigator.clipboard.writeText(cmd.textContent.trim()).then(() => {
        if (btnText) btnText.textContent = 'تم النسخ! ✓';
        UI.showToast('تم نسخ أمر ADB بنجاح إلى الحافظة', 'success');
        setTimeout(() => { if (btnText) btnText.textContent = 'نسخ'; }, 2500);
    });
}

function startAmbientAudioListening() {
    AmbientAudioController.start();
}

function stopAmbientAudioListening() {
    AmbientAudioController.stop();
}

window.AmbientAudioController = AmbientAudioController;
window.WalkieTalkieController = WalkieTalkieController;
window.startAmbientAudioListening = startAmbientAudioListening;
window.stopAmbientAudioListening = stopAmbientAudioListening;
window.toggleAmbientAudioStream = toggleAmbientAudioStream;
window.setAmbientVolume = setAmbientVolume;
window.toggleAmbientMute = toggleAmbientMute;
window.startPushToTalk = startPushToTalk;
window.stopPushToTalk = stopPushToTalk;
window.toggleContinuousTalk = toggleContinuousTalk;
window.requestDeviceOwnerStatus = requestDeviceOwnerStatus;
window.openDeviceOwnerModal = openDeviceOwnerModal;
window.copyAdbCommand = copyAdbCommand;
