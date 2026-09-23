/**
 * WebSocket Client Module
 * Manages live connection to Go Fiber WebSocket hub
 * Auto-reconnects on disconnect, routes all incoming messages to handlers
 */

const WS = {
    _socket: null,
    _reconnectTimer: null,
    _reconnectDelay: 2000,
    _maxDelay: 30000,
    _isIntentionalClose: false,
    _pingInterval: null,

    connect(token) {
        if (!token) return;

        // If an existing socket is already connected or connecting, do not open a duplicate
        if (this._socket && (this._socket.readyState === WebSocket.OPEN || this._socket.readyState === WebSocket.CONNECTING)) {
            console.log('[WS] Socket already active or connecting, skipping duplicate connect.');
            return;
        }

        // Clean up previous timers and pings
        clearTimeout(this._reconnectTimer);
        clearInterval(this._pingInterval);
        this._isIntentionalClose = false;

        const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
        let wsUrl = '';
        if (window.APP_CONFIG?.wsBase && window.APP_CONFIG.wsBase.startsWith('ws')) {
            wsUrl = `${window.APP_CONFIG.wsBase}?token=${encodeURIComponent(token)}`;
        } else if (location.port === '8085') {
            wsUrl = `${proto}//${location.hostname}:8080/ws?token=${encodeURIComponent(token)}`;
        } else {
            wsUrl = `${proto}//${location.host}/ws?token=${encodeURIComponent(token)}`;
        }

        console.log('[WS] Connecting to:', wsUrl);
        try {
            this._socket = new WebSocket(wsUrl);
        } catch (err) {
            console.error('[WS] Failed to create WebSocket:', err);
            UI.setWsStatus('error');
            this._scheduleReconnect();
            return;
        }

        this._socket.onopen = () => {
            console.log('[WS] Connected successfully!');
            this._reconnectDelay = 2000;
            UI.setWsStatus('connected');

            // Send Heartbeat Ping every 25 seconds to keep connection alive through all proxies
            clearInterval(this._pingInterval);
            this._pingInterval = setInterval(() => {
                if (this._socket && this._socket.readyState === WebSocket.OPEN) {
                    this.send('HEARTBEAT_PING', { timestamp: Date.now() });
                }
            }, 25000);
        };

        this._socket.onclose = (event) => {
            console.warn(`[WS] Disconnected (code: ${event.code}, reason: "${event.reason || 'none'}").`);
            clearInterval(this._pingInterval);
            UI.setWsStatus('disconnected');
            if (!this._isIntentionalClose) {
                this._scheduleReconnect();
            }
        };

        this._socket.onerror = (e) => {
            console.error('[WS] Socket error event:', e);
            UI.setWsStatus('error');
        };

        this._socket.onmessage = (event) => {
            try {
                const msg = JSON.parse(event.data);
                this._routeMessage(msg);
            } catch (e) {
                console.warn('[WS] Invalid message received:', event.data);
            }
        };
    },

    disconnect() {
        this._isIntentionalClose = true;
        clearTimeout(this._reconnectTimer);
        clearInterval(this._pingInterval);
        if (this._socket) {
            try {
                this._socket.close(1000, 'User Disconnect');
            } catch (e) {}
            this._socket = null;
        }
        UI.setWsStatus('disconnected');
    },

    _scheduleReconnect() {
        if (this._isIntentionalClose) return;
        clearTimeout(this._reconnectTimer);
        this._reconnectTimer = setTimeout(() => {
            if (!this._isIntentionalClose && window.STATE?.token) {
                console.log(`[WS] Attempting reconnect in ${this._reconnectDelay}ms...`);
                this.connect(window.STATE.token);
            }
        }, this._reconnectDelay);
        this._reconnectDelay = Math.min(this._reconnectDelay * 1.5, this._maxDelay);
    },

    _routeMessage(msg) {
        const type = msg.type || '';
        switch (type) {
            case 'LOCATION_UPDATE':
                const locPayload = msg.payload || msg;
                if (locPayload && locPayload.latitude && locPayload.longitude) {
                    window.STATE.latestLocation = locPayload;
                    if (window.GeofenceMapController && window.GeofenceMapController.updateKidLocation) {
                        window.GeofenceMapController.updateKidLocation(locPayload.latitude, locPayload.longitude);
                    }
                }
                MapController.updateLiveLocation(locPayload);
                break;
            case 'SCREENSHOT_CAPTURED':
                const screenshotPayload = msg.payload || msg;
                if (window.ScreenStreamController) {
                    window.ScreenStreamController.handleIncomingSnapshot(screenshotPayload);
                }
                if (screenshotPayload.error) {
                    UI.displayScreenshotError(screenshotPayload.error);
                } else if (screenshotPayload.image_base64) {
                    UI.displayScreenshot(screenshotPayload.image_base64);
                } else {
                    UI.displayScreenshotError('تعذر استلام بيانات لقطة الشاشة من جهاز الطفل');
                }
                break;
            case 'RISK_ALERT':
                App.onRiskAlert(msg.payload || msg);
                break;
            case 'RISK_ALERT_SAFE_UPDATED':
                if (window.App && window.App.onRiskAlertSafeUpdated) {
                    App.onRiskAlertSafeUpdated(msg.payload || msg);
                }
                break;
            case 'SOS_ALERT':
                App.onSosAlert(msg.payload || msg);
                break;
            case 'LOW_BATTERY_ALERT':
                UI.showToast(`🔋 تنبيه بطارية منخفضة: ${msg.payload?.level || ''}%`, 'warning');
                document.getElementById('cardBatteryLevel').textContent = (msg.payload?.level || '--') + '%';
                break;
            case 'GEOFENCE_ALERT':
                App.onGeofenceAlert(msg.payload || msg);
                break;
            case 'CALLS_SYNC':
            case 'SMS_SYNC':
            case 'FILES_SYNC':
            case 'CONTACTS_SYNC':
            case 'NOTIFICATION_FORWARD':
                App.onDataSync(type, msg.payload || msg);
                break;
            case 'FILE_DATA_RESULT':
                if (window.App && window.App.onFileDataResult) {
                    App.onFileDataResult(msg.payload || msg);
                }
                break;
            case 'DIRECTORY_LIST_RESULT':
                if (window.App && window.App.onDirectoryListResult) {
                    App.onDirectoryListResult(msg.payload || msg);
                }
                break;
            case 'DEVICE_PAIRED': {
                console.log('[WS] Device paired event received:', msg);
                UI.showToast('🎉 تم ربط واقتران جهاز الطفل بنجاح!', 'success');
                if (window.App && window.App.loadChildren) {
                    window.App.loadChildren();
                }
                break;
            }
            case 'DEVICE_ONLINE': {
                const devId = msg.from;
                const dev = STATE.devices?.find(d => d.id === devId);
                if (dev) {
                    dev.status = 'online';
                    dev.is_online = true;
                }
                if (devId === STATE.activeDeviceId) {
                    UI.updateDeviceOnlineStatus(true);
                }
                if (window.App && window.App.renderChildrenCards) {
                    App.renderChildrenCards();
                }
                break;
            }
            case 'DEVICE_OFFLINE': {
                const devId = msg.from;
                const dev = STATE.devices?.find(d => d.id === devId);
                if (dev) {
                    dev.status = 'offline';
                    dev.is_online = false;
                }
                if (devId === STATE.activeDeviceId) {
                    UI.updateDeviceOnlineStatus(false);
                }
                if (window.App && window.App.renderChildrenCards) {
                    App.renderChildrenCards();
                }
                break;
            }
            case 'HEARTBEAT_PING': {
                const devId = msg.from;
                const dev = STATE.devices?.find(d => d.id === devId);
                if (dev) {
                    dev.status = 'online';
                    dev.is_online = true;
                    if (msg.payload?.battery_level !== undefined) {
                        dev.battery_level = msg.payload.battery_level;
                    }
                }
                if (devId === STATE.activeDeviceId || !devId) {
                    UI.updateDeviceOnlineStatus(true, msg.payload?.battery_level);
                }
                if (window.App && window.App.renderChildrenCards) {
                    App.renderChildrenCards();
                }
                break;
            }
            case 'HEARTBEAT_PONG':
                // Server confirmed WebSocket connection liveness
                break;
            case 'MONITORING_STATUS_CHANGED':
                try {
                    const p = typeof msg.payload === 'string' ? JSON.parse(msg.payload) : (msg.payload || msg);
                    const paused = p.is_monitoring_paused ?? false;
                    if (typeof updateMasterMonitoringUI === 'function') {
                        updateMasterMonitoringUI(paused);
                    }
                } catch (e) {}
                break;
            case 'WEB_FILTER_UPDATED':
                try {
                    const p = typeof msg.payload === 'string' ? JSON.parse(msg.payload) : (msg.payload || msg);
                    if (typeof onWebFilterUpdatedWS === 'function') {
                        onWebFilterUpdatedWS(p);
                    }
                } catch (e) {}
                break;
            case 'BROWSER_HISTORY_SYNCED':
                try {
                    if (typeof loadBrowserHistory === 'function') {
                        loadBrowserHistory(true);
                    }
                } catch (e) {}
                break;
            case 'RTC_ANSWER':
            case 'RTC_ICE_CANDIDATE':
            case 'STREAM_ERROR':
                WebRTCController.handleSignaling(msg);
                if (window.ScreenStreamController) {
                    window.ScreenStreamController.handleSignaling(msg);
                }
                if (window.AmbientAudioController) {
                    window.AmbientAudioController.handleSignaling(msg);
                }
                if (window.WalkieTalkieController) {
                    window.WalkieTalkieController.handleSignaling(msg);
                }
                break;
            case 'SIM_SWAP_ALERT':
                const simPayload = msg.payload || msg;
                const simMsg = `🚨 تنبيه أمني عاجل: تم رصد تغيير أو إزالة شريحة الاتصال (SIM)! المشغل: ${simPayload.new_operator || 'غير معروف'}`;
                UI.showToast(simMsg, 'danger');
                if (window.App && window.App.onRiskAlert) {
                    window.App.onRiskAlert({
                        risk_level: 'CRITICAL',
                        category: 'SIM_SWAP',
                        message: simMsg,
                        details: simPayload,
                        timestamp: Date.now()
                    });
                }
                break;
            case 'AIRPLANE_MODE_ALERT':
                const airPayload = msg.payload || msg;
                const airStatus = airPayload.enabled ? 'تفعيل' : 'تعطيل';
                const airMsg = `✈️ تنبيه أمني: قام الطفل بـ (${airStatus}) وضع الطيران على الجهاز`;
                UI.showToast(airMsg, airPayload.enabled ? 'warning' : 'info');
                if (window.App && window.App.onRiskAlert && airPayload.enabled) {
                    window.App.onRiskAlert({
                        risk_level: 'HIGH',
                        category: 'AIRPLANE_MODE',
                        message: airMsg,
                        details: airPayload,
                        timestamp: Date.now()
                    });
                }
                break;
            case 'DEVICE_OWNER_STATUS':
                const doPayload = typeof msg.payload === 'string' ? JSON.parse(msg.payload) : (msg.payload || msg);
                const isDO = doPayload.is_device_owner ?? false;
                const badge = document.getElementById('badgeDeviceOwner');
                if (badge) {
                    badge.textContent = isDO ? 'نشط كـ Device Owner 🛡️' : 'غير مفعل (وضع عادي)';
                    badge.style.background = isDO ? 'rgba(16, 185, 129, 0.2)' : 'rgba(239, 68, 68, 0.2)';
                    badge.style.color = isDO ? '#10b981' : '#ef4444';
                }
                const uninstStat = document.getElementById('statUninstallBlock');
                if (uninstStat) {
                    uninstStat.textContent = isDO ? 'مفعل ومحمي 🔒' : 'غير مدعوم (يتطلب Device Owner)';
                    uninstStat.style.color = isDO ? '#10b981' : '#9ca3af';
                }
                const factoryStat = document.getElementById('statFactoryReset');
                if (factoryStat) {
                    factoryStat.textContent = isDO ? 'مفعل ومحمي 🔒' : 'غير مدعوم (يتطلب Device Owner)';
                    factoryStat.style.color = isDO ? '#10b981' : '#9ca3af';
                }
                const safeBootStat = document.getElementById('statSafeBoot');
                if (safeBootStat) {
                    safeBootStat.textContent = isDO ? 'مفعل ومحمي 🔒' : 'غير مدعوم (يتطلب Device Owner)';
                    safeBootStat.style.color = isDO ? '#10b981' : '#9ca3af';
                }
                const appsControlStat = document.getElementById('statAppsControl');
                if (appsControlStat) {
                    appsControlStat.textContent = isDO ? 'مفعل ومحمي 🔒' : 'غير مدعوم (يتطلب Device Owner)';
                    appsControlStat.style.color = isDO ? '#10b981' : '#9ca3af';
                }
                UI.showToast(isDO ? 'وضع مالك الجهاز (Device Owner) نشط ومحمي' : 'حالة الجهاز: وضع عادي (غير مفعل كـ Device Owner)', isDO ? 'success' : 'info');
                break;
            default:
                console.log('[WS] Unhandled message type:', type);
        }
    },

    send(type, payload = {}, to = null) {
        if (!this._socket || this._socket.readyState !== WebSocket.OPEN) {
            console.warn('[WS] Cannot send message, socket not open:', type);
            return false;
        }

        let targetTo = to;
        let actualPayload = payload;

        if (typeof payload === 'object' && payload !== null) {
            if (!targetTo) {
                targetTo = payload.to || payload.device_id;
            }
            if (payload.payload !== undefined && typeof payload.payload === 'object') {
                actualPayload = payload.payload;
            }
        }

        if (!targetTo && window.STATE?.activeDeviceId) {
            targetTo = window.STATE.activeDeviceId;
        }

        const msg = {
            type: type,
            payload: actualPayload,
            timestamp: Date.now()
        };

        if (targetTo) {
            msg.to = targetTo;
            msg.device_id = targetTo;
        }

        this._socket.send(JSON.stringify(msg));
        return true;
    }
};

window.WS = WS;

window.reconnectWebSocket = function() {
    if (!window.STATE?.token) {
        if (typeof logout === 'function') logout();
        return;
    }
    UI.setWsStatus('syncing');
    UI.showToast('جاري إعادة الاتصال بالسيرفر...', 'info');
    if (typeof WS !== 'undefined') {
        WS.disconnect();
        setTimeout(() => WS.connect(window.STATE.token), 300);
    }
};
