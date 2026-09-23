/**
 * REST API Client Module
 * Handles all HTTP communication with Go Fiber backend API
 */

const API = {
    get base() {
        if (window.APP_CONFIG?.apiBase && window.APP_CONFIG.apiBase.startsWith('http')) {
            return window.APP_CONFIG.apiBase;
        }
        if (location.port === '8085') {
            return `${location.protocol}//${location.hostname}:8080/api/v1`;
        }
        return window.APP_CONFIG?.apiBase || '/api/v1';
    },

    _headers() {
        const h = { 'Content-Type': 'application/json' };
        if (window.STATE?.token) h['Authorization'] = 'Bearer ' + window.STATE.token;
        return h;
    },

    async _request(method, path, body = null) {
        const opts = { method, headers: this._headers() };
        if (body) opts.body = JSON.stringify(body);
        try {
            const res = await fetch(this.base + path, opts);
            const data = await res.json().catch(() => ({}));
            if (res.status === 402 || data.error === 'subscription_expired' || data.error === 'subscription_suspended') {
                if (window.UI?.showSubscriptionExpiredModal) {
                    window.UI.showSubscriptionExpiredModal(data);
                }
            }
            if (!res.ok) throw new Error(data.error || data.message || `HTTP ${res.status}`);
            return data;
        } catch (err) {
            console.error(`[API] ${method} ${path} failed:`, err.message);
            throw err;
        }
    },

    get: (path) => API._request('GET', path),
    post: (path, body) => API._request('POST', path, body),
    del: (path) => API._request('DELETE', path),

    // === Auth & Subscription ===
    login: (email, password) => API.post('/auth/login', { email, password }),
    register: (param1, password, full_name) => {
        if (typeof param1 === 'object' && param1 !== null) {
            return API.post('/auth/register', { role: 'parent', ...param1 });
        }
        return API.post('/auth/register', { email: param1, password, full_name, role: 'parent' });
    },
    getMe: () => API.get('/auth/me'),
    getMySubscription: () => API.get('/subscription/my'),

    // === Children & Devices ===
    listDevices: () => API.get('/devices/'),
    listChildren: () => API.get('/devices/children'),
    createChild: (name) => API.post('/devices/children', { name }),
    generatePairCode: (childId) => API.post(`/devices/children/${childId}/pair-code`, {}),
    sendCommand: (deviceId, action, params = {}) => API.post(`/devices/${deviceId}/command`, { action, params }),
    deleteDevice: (deviceId) => API.del(`/devices/${deviceId}`),
    deleteChild: (childId) => API.del(`/devices/children/${childId}`),

    // === Location ===
    getLatestLocation: (deviceId) => API.get(`/devices/${deviceId}/location/latest`),
    getLocationHistory: (deviceId, hours = 24) => API.get(`/devices/${deviceId}/location/history?hours=${hours}`),

    // === Geofences ===
    getGeofences: (childId) => API.get(`/geofences/child/${childId}`),
    createGeofence: (data) => API.post('/geofences/', data),
    deleteGeofence: (id) => API.del(`/geofences/${id}`),

    // === Apps ===
    getApps: (deviceId) => API.get(`/devices/${deviceId}/apps`),
    toggleAppBlock: (deviceId, packageName, isBlocked) => API.post(`/devices/${deviceId}/apps/block`, { package_name: packageName, is_blocked: isBlocked }),
    getUsage: (deviceId) => API.get(`/devices/${deviceId}/usage`),

    // === Screen Time ===
    getScreenTimeRule: (deviceId) => API.get(`/devices/${deviceId}/screen-time-rules`),
    saveScreenTimeRule: (deviceId, data) => API.post(`/devices/${deviceId}/screen-time-rules`, data),

    // === Data Logs & Media Gallery & File Explorer ===
    getCalls: (deviceId) => API.get(`/devices/${deviceId}/calls`),
    getSMS: (deviceId) => API.get(`/devices/${deviceId}/sms`),
    getContacts: (deviceId) => API.get(`/devices/${deviceId}/contacts`),
    getNotifications: (deviceId) => API.get(`/devices/${deviceId}/notifications`),
    getFiles: (deviceId) => API.get(`/devices/${deviceId}/files`),
    fetchFileData: (deviceId, filePath) => API.sendCommand(deviceId, 'FETCH_FILE_DATA', { file_path: filePath }),
    listDirectory: (deviceId, dirPath = '') => API.sendCommand(deviceId, 'LIST_DIRECTORY', { directory_path: dirPath }),
    getRiskAlerts: (deviceId) => API.get(`/devices/${deviceId}/risk-alerts`),
    markRiskAlertSafe: (deviceId, alertId) => API.post(`/devices/${deviceId}/risk-alerts/${alertId}/mark-safe`, {}),

    // === WebRTC ===
    getWebRTCConfig: () => API.get('/webrtc/config'),

    // === Geofences ===
    getGeofences: (childId) => API.get(`/geofences/child/${childId}`),
    createGeofence: (data) => API.post('/geofences', data),
    deleteGeofence: (id) => API.del(`/geofences/${id}`),
    getGeofenceEvents: (childId) => API.get(`/geofences/events/${childId}`),

    // === Web Filter ===
    getWebFilter: (deviceId) => API.get(`/devices/${deviceId}/web-filter`),
    createWebFilterRule: (deviceId, data) => API.post(`/devices/${deviceId}/web-filter`, data),
    toggleWebFilterEngine: (deviceId, enabled) => API._request('PUT', `/devices/${deviceId}/web-filter/toggle-engine`, { enabled }),
    toggleAllWebFilterRules: (deviceId, enabled) => API._request('PUT', `/devices/${deviceId}/web-filter/toggle-all`, { enabled }),
    toggleWebFilterRule: (deviceId, ruleId, isActive) => API._request('PUT', `/devices/${deviceId}/web-filter/${ruleId}/toggle`, { is_active: isActive }),
    deleteWebFilterRule: (deviceId, ruleId) => API.del(`/devices/${deviceId}/web-filter/${ruleId}`),
    seedWebFilterDefaults: (deviceId) => API.post(`/devices/${deviceId}/web-filter/seed-defaults`, {}),

    // Browser History & Safe Search
    getBrowserHistory: (deviceId, params = {}) => {
        const q = new URLSearchParams(params).toString();
        return API.get(`/devices/${deviceId}/browser-history${q ? '?' + q : ''}`);
    },
    getBrowserHistoryStats: (deviceId) => API.get(`/devices/${deviceId}/browser-history/stats`),
    clearBrowserHistory: (deviceId) => API.del(`/devices/${deviceId}/browser-history`),
    quickBlockBrowserDomain: (deviceId, data) => API.post(`/devices/${deviceId}/browser-history/quick-block`, data),
};

window.API = API;
