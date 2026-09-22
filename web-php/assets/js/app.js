/**
 * Parental Control Platform - Master Application Controller
 * Coordinates State, Child Switcher, Commands, Data Sync & Real-Time Events
 */

window.STATE = {
    token: localStorage.getItem('parent_jwt_token') || '',
    familyKey: localStorage.getItem('family_e2ee_key') || 'ParentSecretPassphrase2026',
    activeDeviceId: localStorage.getItem('active_device_id') || '',
    activeChildId: localStorage.getItem('active_child_id') || '',
    subscription: null,
    children: [],
    devices: [],
    apps: [],
    contacts: [],
    screenTimeChart: null,
};

function escapeHtml(str) {
    if (str === null || str === undefined) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}
// ==========================================================================
// Permanent Auto-Renewing Pairing Manager for Unpaired Children
// إدارة أكواد الاقتران الدائمة والمتجددة تلقائياً
// ==========================================================================
window.PairingManager = {
    codes: {},   // { [childId]: { code, familyId, expiresAt, remainingSeconds, timer } }
    loading: {}, // { [childId]: boolean }

    async getOrGenerateCode(childId, force = false) {
        if (!childId) return null;
        const entry = this.codes[childId];
        const now = Date.now();

        // If code exists, not forced, and has > 30s remaining, return cached
        if (entry && !force && entry.expiresAt > now + 30000) {
            return entry.code;
        }

        if (this.loading[childId]) return entry?.code || null;
        this.loading[childId] = true;

        try {
            const res = await API.generatePairCode(childId);
            const data = res.data || res;
            const code = String(data.code || '000000');
            const familyId = data.family_id || '';
            const validitySec = data.expires_in_seconds || (15 * 60);

            if (entry && entry.timer) {
                clearInterval(entry.timer);
            }

            const expiresAt = Date.now() + (validitySec * 1000);
            const newEntry = {
                code: code,
                familyId: familyId,
                expiresAt: expiresAt,
                remainingSeconds: validitySec,
                timer: null
            };

            // Setup auto-renew timer
            newEntry.timer = setInterval(() => {
                const curLeft = Math.max(0, Math.floor((newEntry.expiresAt - Date.now()) / 1000));
                newEntry.remainingSeconds = curLeft;

                // Auto-refresh when <= 30 seconds remaining to ensure it NEVER expires
                if (curLeft <= 30) {
                    clearInterval(newEntry.timer);
                    newEntry.timer = null;
                    console.log(`[PairingManager] Auto-renewing pair code for child ${childId}...`);
                    window.PairingManager.getOrGenerateCode(childId, true);
                    return;
                }

                // If active child is this child, update countdown in hero
                if (STATE.activeChildId === childId) {
                    const heroCountdown = document.getElementById('unpairedHeroCountdown');
                    if (heroCountdown) {
                        const m = String(Math.floor(curLeft / 60)).padStart(2, '0');
                        const s = String(curLeft % 60).padStart(2, '0');
                        heroCountdown.textContent = `${m}:${s}`;
                    }
                }
            }, 1000);

            this.codes[childId] = newEntry;

            // Re-render UI elements
            this.updateAllUI(childId);

            return code;
        } catch (err) {
            console.error(`[PairingManager] Failed to generate pair code for child ${childId}:`, err);
            return null;
        } finally {
            this.loading[childId] = false;
        }
    },

    syncUnpairedChildren() {
        if (!Array.isArray(STATE.children)) return;
        STATE.children.forEach(child => {
            const hasDev = STATE.devices && STATE.devices.some(d => d.child_id === child.id);
            if (!hasDev) {
                this.getOrGenerateCode(child.id);
            } else {
                if (this.codes[child.id]?.timer) {
                    clearInterval(this.codes[child.id].timer);
                    delete this.codes[child.id];
                }
            }
        });
        this.renderQuickBar();
        this.renderOverviewHero();
    },

    updateAllUI(childId) {
        if (typeof App !== 'undefined' && App.renderChildrenCards) {
            App.renderChildrenCards();
        }
        this.renderQuickBar();
        if (!childId || STATE.activeChildId === childId) {
            this.renderOverviewHero();
        }
    },

    renderOverviewHero() {
        const hero = document.getElementById('overviewUnpairedHero');
        if (!hero) return;

        const child = STATE.children?.find(c => c.id === STATE.activeChildId);
        const hasDev = STATE.devices?.some(d => d.child_id === STATE.activeChildId);

        // If no child or child has a paired device, hide hero
        if (!child || hasDev) {
            hero.style.display = 'none';
            return;
        }

        hero.style.display = 'block';

        const nameEl = document.getElementById('unpairedChildName');
        if (nameEl) nameEl.textContent = child.name;

        const entry = this.codes[child.id];
        const digitsWrapper = document.getElementById('unpairedDigitsWrapper');
        const countdownEl = document.getElementById('unpairedHeroCountdown');
        const qrContainer = document.getElementById('unpairedHeroQrCode');

        if (entry && entry.code) {
            const codeStr = String(entry.code).padStart(6, '0');
            if (digitsWrapper) {
                digitsWrapper.innerHTML = codeStr.split('').map(d => `<span class="unpaired-digit-box">${d}</span>`).join('');
            }
            if (countdownEl) {
                const curLeft = Math.max(0, Math.floor((entry.expiresAt - Date.now()) / 1000));
                const m = String(Math.floor(curLeft / 60)).padStart(2, '0');
                const s = String(curLeft % 60).padStart(2, '0');
                countdownEl.textContent = `${m}:${s}`;
            }

            if (qrContainer && typeof QRCode !== 'undefined') {
                qrContainer.innerHTML = '';
                const qrPayload = JSON.stringify({
                    code: entry.code,
                    family_id: entry.familyId,
                    child_id: child.id,
                    server_url: window.APP_CONFIG?.wsBase?.replace('/ws', '') || window.location.origin
                });
                new QRCode(qrContainer, {
                    text: qrPayload,
                    width: 140,
                    height: 140,
                    colorDark: "#0f172a",
                    colorLight: "#ffffff",
                    correctLevel: QRCode.CorrectLevel.M
                });
            }
        } else {
            if (digitsWrapper) {
                digitsWrapper.innerHTML = `<span class="unpaired-digit-box"><i class="fa-solid fa-circle-notch fa-spin" style="font-size: 1.2rem;"></i></span>`;
            }
            this.getOrGenerateCode(child.id);
        }
    },

    renderQuickBar() {
        const bar = document.getElementById('unpairedDevicesQuickBar');
        if (!bar) return;

        if (!STATE.children || STATE.children.length === 0) {
            bar.style.display = 'none';
            return;
        }

        const unpaired = STATE.children.filter(child => {
            return !STATE.devices || !STATE.devices.some(d => d.child_id === child.id);
        });

        if (unpaired.length === 0) {
            bar.style.display = 'none';
            bar.innerHTML = '';
            return;
        }

        bar.style.display = 'block';
        bar.innerHTML = `
            <div class="unpaired-alert-ribbon">
                <div class="unpaired-ribbon-left">
                    <i class="fa-solid fa-triangle-exclamation ribbon-icon"></i>
                    <span class="ribbon-title">أجهزة بانتظار الاقتران:</span>
                    <div class="ribbon-chips">
                        ${unpaired.map(child => {
                            const entry = this.codes[child.id];
                            const code = entry?.code ? entry.code : '...';
                            return `
                                <div class="ribbon-child-chip" onclick="App.selectChild('${child.id}', '')" title="انقر لعرض تفاصيل الاقتران">
                                    <span class="ribbon-name">${escapeHtml(child.name)}</span>
                                    <span class="ribbon-code"><i class="fa-solid fa-key"></i> ${code}</span>
                                    <button class="btn-copy-chip" onclick="event.stopPropagation(); window.copySpecificCode('${code}')" title="نسخ الكود">
                                        <i class="fa-regular fa-copy"></i>
                                    </button>
                                </div>
                            `;
                        }).join('')}
                    </div>
                </div>
                <div class="ribbon-hint">
                    <i class="fa-solid fa-circle-info"></i> أدخل الكود في تطبيق سَنَد على هاتف أو كمبيوتر الطفل للربط الفوري.
                </div>
            </div>
        `;
    }
};

window.copyActiveUnpairedCode = function() {
    const childId = STATE.activeChildId;
    const entry = window.PairingManager?.codes[childId];
    if (entry && entry.code) {
        navigator.clipboard.writeText(entry.code).then(() => {
            UI.showToast(`تم نسخ رمز الاقتران (${entry.code}) إلى الحافظة`, 'success');
        }).catch(() => {
            UI.showToast(`كود الاقتران: ${entry.code}`, 'info');
        });
    } else {
        UI.showToast('جاري استخراج رمز الاقتران...', 'warning');
    }
};

window.renewActiveUnpairedCode = async function() {
    const childId = STATE.activeChildId;
    if (!childId) return;
    const icon = document.getElementById('unpairedRenewIcon');
    if (icon) icon.classList.add('fa-spin');
    try {
        UI.showToast('جاري تجديد كود الاقتران...', 'info');
        await window.PairingManager.getOrGenerateCode(childId, true);
        UI.showToast('تم تجديد كود الاقتران بنجاح', 'success');
    } catch (e) {
        UI.showToast('تعذر تجديد الكود: ' + e.message, 'error');
    } finally {
        if (icon) icon.classList.remove('fa-spin');
    }
};

window.copySpecificCode = function(code) {
    if (!code || code === '...') return;
    navigator.clipboard.writeText(code).then(() => {
        UI.showToast(`تم نسخ الرمز (${code}) بنجاح`, 'success');
    }).catch(() => {
        UI.showToast(`الرمز: ${code}`, 'info');
    });
};

const App = {
    async init() {
        console.log('🚀 Initializing Parental Control Platform (PHP Modular Edition)...');

        const authScreen = document.getElementById('authScreen');
        const appLayout = document.getElementById('dashboardAppLayout');

        // Check auth token
        if (!STATE.token) {
            if (authScreen) authScreen.style.display = 'flex';
            if (appLayout) appLayout.style.display = 'none';
            return;
        }

        // Authenticated: reveal dashboard and hide auth screen
        if (authScreen) authScreen.style.display = 'none';
        if (appLayout) appLayout.style.display = 'grid';

        // Initialize Map
        MapController.init();

        // Connect WebSocket
        WS.connect(STATE.token);

        // Load Subscription Info & Quota
        await this.loadSubscription();

        // Load Children & Devices
        await this.loadChildren();

        // If we have an active device, load all its monitoring data
        if (STATE.activeDeviceId) {
            await this.loadAllActiveDeviceData();
        }

        // Support direct hash navigation on page load or refresh (e.g. #alerts, #location)
        const initialHash = window.location.hash ? window.location.hash.replace('#', '') : '';
        if (initialHash && typeof switchSection === 'function') {
            switchSection(initialHash);
        }
    },

    // === Subscription & Quota Management ===
    async loadSubscription() {
        try {
            const sub = await API.getMySubscription();
            STATE.subscription = sub;
            UI.updateSubscriptionUI(sub);
        } catch (err) {
            console.error('Failed to load subscription:', err);
            if (err.message && (err.message.includes('401') || err.message.includes('Unauthorized'))) {
                logout();
            }
        }
    },

    // === Children & Devices Management ===
    async loadChildren() {
        try {
            const res = await API.listChildren();
            const children = res.data || res.children || res || [];
            STATE.children = Array.isArray(children) ? children : [];

            // Also load raw devices to match
            const devRes = await API.listDevices();
            const devices = devRes.data || devRes.devices || devRes || [];
            STATE.devices = Array.isArray(devices) ? devices : [];

            this.renderChildrenCards();

            // Set default active child/device if not set
            if ((!STATE.activeDeviceId || !STATE.activeChildId) && STATE.children.length > 0) {
                const first = STATE.children[0];
                STATE.activeChildId = first.id;
                // Find associated device
                const dev = STATE.devices.find(d => d.child_id === first.id) || STATE.devices[0];
                if (dev) {
                    STATE.activeDeviceId = dev.id;
                    localStorage.setItem('active_device_id', dev.id);
                    localStorage.setItem('active_child_id', first.id);
                    if (dev.last_location && dev.last_location.latitude) {
                        STATE.latestLocation = dev.last_location;
                        if (window.GeofenceMapController && window.GeofenceMapController.updateKidLocation) {
                            GeofenceMapController.updateKidLocation(dev.last_location.latitude, dev.last_location.longitude);
                        }
                    }
                } else {
                    STATE.activeDeviceId = '';
                    localStorage.setItem('active_child_id', first.id);
                    localStorage.removeItem('active_device_id');
                }
            }

            this.updateActiveDeviceUI();

            // Auto-sync pairing codes for all unpaired children
            if (window.PairingManager) {
                window.PairingManager.syncUnpairedChildren();
            }
        } catch (err) {
            console.error('Failed to load children:', err);
            if (err.message.includes('401') || err.message.includes('Unauthorized')) {
                logout();
            }
        }
    },

    renderChildrenCards() {
        const container = document.getElementById('childrenCardsContainer');
        if (!container) return;

        if (STATE.children.length === 0) {
            container.innerHTML = `
                <div class="no-children-banner">
                    <i class="fa-solid fa-child"></i>
                    <span>لم يتم ربط أي طفل بعد. اضغط على زر "إضافة طفل / جهاز جديد" للبدء بالاقتران.</span>
                </div>
            `;
            return;
        }

        container.innerHTML = STATE.children.map(child => {
            const dev = STATE.devices.find(d => d.child_id === child.id);
            const isSelected = child.id === STATE.activeChildId;
            const isOnline = dev ? (dev.status === 'online' || dev.is_online === true) : false;
            const battery = dev?.battery_level !== undefined && dev?.battery_level !== null ? dev.battery_level : '--';
            const model = dev ? (dev.model || 'جهاز ذكي') : 'بانتظار الاقتران';
            const isWindows = dev?.os_type === 'windows' ||
                              (dev?.model && dev.model.toLowerCase().includes('windows')) ||
                              (dev?.os_version && dev.os_version.toLowerCase().includes('windows'));
            const deviceIcon = dev ? (isWindows ? 'fa-laptop' : 'fa-mobile-screen-button') : 'fa-qrcode';

            const pairEntry = window.PairingManager ? window.PairingManager.codes[child.id] : null;
            const pairCodeBadge = (!dev && pairEntry?.code) ? 
                `<span class="pairing-code-tag" title="كود الاقتران الدائم"><i class="fa-solid fa-key"></i> <span class="code-val">${pairEntry.code}</span></span>` : '';

            return `
                <div class="child-card ${isSelected ? 'active' : ''} ${!dev ? 'unpaired-child-chip' : ''}" onclick="App.selectChild('${child.id}', '${dev ? dev.id : ''}')">
                    <div class="child-avatar">
                        <i class="fa-solid ${deviceIcon}"></i>
                    </div>
                    <div class="child-info">
                        <div class="child-name">${escapeHtml(child.name)} ${pairCodeBadge}</div>
                        <div class="child-model">${escapeHtml(model)}</div>
                        <div class="child-meta">
                            ${dev ? `<span class="child-battery"><i class="fa-solid fa-battery-half"></i> ${battery}%</span>` : ''}
                            <span class="child-status ${isOnline ? 'online' : ''}">${dev ? (isOnline ? 'متصل' : 'غير متصل') : '⏳ بانتظار الاقتران'}</span>
                        </div>
                    </div>
                    <button class="child-delete-btn" onclick="event.stopPropagation(); ${dev ? `openDeleteDeviceModal('${dev.id}', '${escapeHtml(child.name)}', '${escapeHtml(model)}', '${child.id}')` : `openDeleteChildModal('${child.id}', '${escapeHtml(child.name)}')`}" title="${dev ? 'حذف هذا الجهاز وفك كافة القيود' : 'حذف ملف هذا الطفل'}">
                        <i class="fa-solid fa-trash-can"></i>
                    </button>
                </div>
            `;
        }).join('');
    },

    selectChild(childId, deviceId) {
        STATE.activeChildId = childId;
        STATE.activeDeviceId = deviceId || '';
        localStorage.setItem('active_child_id', childId);
        if (deviceId) {
            localStorage.setItem('active_device_id', deviceId);
        } else {
            localStorage.removeItem('active_device_id');
        }

        const dev = STATE.devices.find(d => d.id === deviceId);
        if (dev && dev.last_location && dev.last_location.latitude) {
            STATE.latestLocation = dev.last_location;
            if (window.GeofenceMapController && window.GeofenceMapController.updateKidLocation) {
                GeofenceMapController.updateKidLocation(dev.last_location.latitude, dev.last_location.longitude);
            }
        }

        this.renderChildrenCards();
        this.updateActiveDeviceUI();
        if (deviceId) {
            this.loadAllActiveDeviceData();
        }
        UI.showToast('تم التبديل إلى جهاز الطفل المحدد', 'info');
    },

    updateActiveDeviceUI() {
        const child = STATE.children.find(c => c.id === STATE.activeChildId);
        const dev = STATE.devices.find(d => d.id === STATE.activeDeviceId);

        const childName = child ? child.name : 'جهاز الطفل';
        const modelName = dev ? dev.model : (child ? 'بانتظار الاقتران' : 'Android Device');

        document.getElementById('sideChildName').textContent = childName;
        document.getElementById('sideModelName').textContent = modelName;
        document.getElementById('cardDeviceModel').textContent = `${childName} (${modelName})`;

        if (dev) {
            UI.updateDeviceOnlineStatus(dev.status === 'online' || dev.is_online === true, dev.battery_level);
            if (typeof updateMasterMonitoringUI === 'function') {
                updateMasterMonitoringUI(dev.is_monitoring_paused || false);
            }
        } else {
            UI.updateDeviceOnlineStatus(false, null);
        }

        // Render / refresh unpaired hero card
        if (window.PairingManager) {
            window.PairingManager.renderOverviewHero();
        }
    },

    async loadAllActiveDeviceData() {
        if (!STATE.activeDeviceId) return;
        const spin = document.getElementById('refreshSpinIcon');
        if (spin) spin.classList.add('fa-spin');

        await Promise.allSettled([
            this.loadLatestLocation(),
            this.loadApps(),
            this.loadCalls(),
            this.loadSMS(),
            this.loadContacts(),
            this.loadNotifications(),
            this.loadFiles(),
            this.loadRiskAlerts(),
            this.loadScreenTimeRules(),
            this.loadGeofences(),
            (window.loadBrowserHistory ? window.loadBrowserHistory() : Promise.resolve())
        ]);

        if (spin) spin.classList.remove('fa-spin');
    },

    // === Location ===
    async loadLatestLocation() {
        try {
            const res = await API.getLatestLocation(STATE.activeDeviceId);
            const loc = res.data || res.location || res;
            if (loc && loc.latitude) {
                STATE.latestLocation = loc;
                MapController.updateLiveLocation(loc);
                if (loc.latitude && loc.longitude) {
                    MapController.marker?.setLatLng([loc.latitude, loc.longitude]);
                    MapController.map?.setView([loc.latitude, loc.longitude], 15);
                }
                if (window.GeofenceMapController && window.GeofenceMapController.updateKidLocation) {
                    GeofenceMapController.updateKidLocation(loc.latitude, loc.longitude);
                }
            }
        } catch (e) { console.warn('Load location failed:', e.message); }
    },

    // === Apps & Blocker ===
    async loadApps(forceRefresh = false) {
        try {
            const res = await API.getApps(STATE.activeDeviceId);
            STATE.apps = res.data || res.apps || res || [];
            this.renderAppsTable(STATE.apps);
            document.getElementById('appsCountBadge').textContent = STATE.apps.length;
            document.getElementById('countAllApps').textContent = STATE.apps.length;
            document.getElementById('countBlockedApps').textContent = STATE.apps.filter(a => a.is_blocked).length;
            document.getElementById('countUserApps').textContent = STATE.apps.filter(a => !a.is_system).length;
            document.getElementById('countSystemApps').textContent = STATE.apps.filter(a => a.is_system).length;
        } catch (e) { console.warn('Load apps failed:', e.message); }
    },

    renderAppsTable(appsList) {
        const tbody = document.getElementById('appsTableBody');
        if (!tbody) return;

        if (!Array.isArray(appsList) || appsList.length === 0) {
            tbody.innerHTML = `<tr><td colspan="6" class="text-center text-muted">لا توجد تطبيقات مدرجة</td></tr>`;
            return;
        }

        tbody.innerHTML = appsList.map((app, idx) => `
            <tr>
                <td>${idx + 1}</td>
                <td>
                    <div class="app-row-title">
                        <div class="app-row-icon"><i class="fa-solid fa-cube"></i></div>
                        <div>
                            <div class="app-row-name">${app.app_name || app.name || 'تطبيق'}</div>
                        </div>
                    </div>
                </td>
                <td><code>${app.package_name || app.package || ''}</code></td>
                <td><span class="badge ${app.is_system ? 'badge-secondary' : 'badge-primary'}">${app.is_system ? 'نظام' : 'مستخدم'}</span></td>
                <td><span class="badge ${app.is_blocked ? 'badge-danger' : 'badge-success'}">${app.is_blocked ? 'محظور' : 'نشط ومتاح'}</span></td>
                <td style="text-align: center;">
                    <label class="switch-toggle">
                        <input type="checkbox" ${app.is_blocked ? 'checked' : ''} onchange="App.toggleAppBlock('${app.package_name || app.package || app.id}', this.checked)">
                        <span class="slider round"></span>
                    </label>
                </td>
            </tr>
        `).join('');
    },

    async toggleAppBlock(packageName, isBlocked) {
        try {
            await API.toggleAppBlock(STATE.activeDeviceId, packageName, isBlocked);
            // Also send direct real-time WS command as redundancy
            WS.send('DEVICE_COMMAND', {
                to: STATE.activeDeviceId,
                device_id: STATE.activeDeviceId,
                action: isBlocked ? 'BLOCK_APP' : 'UNBLOCK_APP',
                params: { package_name: packageName }
            });
            UI.showToast(isBlocked ? 'تم إرسال أمر حظر التطبيق بنجاح' : 'تم إرسال أمر فك حظر التطبيق بنجاح', 'success');
            // update local state
            const app = STATE.apps.find(a => (a.package_name || a.package || a.id) === packageName);
            if (app) app.is_blocked = isBlocked;
            this.renderAppsTable(STATE.apps);
        } catch (e) {
            UI.showToast('فشل تحديث حالة التطبيق: ' + e.message, 'error');
        }
    },

    // === Calls Log ===
    async loadCalls() {
        try {
            if (!STATE.activeDeviceId) return;
            const res = await API.getCalls(STATE.activeDeviceId);
            const calls = Array.isArray(res) ? res : (res.data || res.calls || []);
            const badge = document.getElementById('callsCountBadge');
            if (badge) badge.textContent = calls.length;
            const tbody = document.getElementById('callsTableBody');
            if (!tbody) return;

            if (calls.length === 0) {
                tbody.innerHTML = `<tr><td colspan="5" class="text-center text-muted">لا يوجد سجل مكالمات حتى الآن</td></tr>`;
                return;
            }

            const renderedRows = await Promise.all(calls.map(async (c) => {
                try {
                    const rawName = c.name || c.contact_name || c.caller_name || '';
                    const rawNumber = c.number || c.phone_number || '';
                    const name = rawName ? await CryptoEngine.decryptIfNeeded(rawName) : (rawNumber || 'جهة اتصال غير معروفة');
                    const number = rawNumber ? await CryptoEngine.decryptIfNeeded(rawNumber) : '';

                    let durationText = '0 ثانية';
                    const sec = c.duration_seconds ?? c.duration;
                    if (sec !== undefined && sec !== null) {
                        const s = Number(sec);
                        if (s >= 60) {
                            const mins = Math.floor(s / 60);
                            const remSec = s % 60;
                            durationText = `${mins} دقيقة ${remSec > 0 ? `${remSec} ثانية` : ''}`;
                        } else {
                            durationText = `${s} ثانية`;
                        }
                    }

                    const ts = c.timestamp ? Number(c.timestamp) : (c.created_at ? new Date(c.created_at).getTime() : null);
                    const timeText = ts ? new Date(ts).toLocaleString('ar-EG') : '---';

                    const callType = (c.call_type || 'OUTGOING').toUpperCase();
                    let typeClass = 'badge-primary';
                    let typeArabic = 'صادرة 🔵';
                    if (callType === 'INCOMING') {
                        typeClass = 'badge-success';
                        typeArabic = 'واردة 🟢';
                    } else if (callType === 'OUTGOING') {
                        typeClass = 'badge-primary';
                        typeArabic = 'صادرة 🔵';
                    } else if (callType === 'MISSED') {
                        typeClass = 'badge-danger';
                        typeArabic = 'فائتة 🔴';
                    } else if (callType === 'REJECTED') {
                        typeClass = 'badge-danger';
                        typeArabic = 'مرفوضة ⛔';
                    }

                    return `
                        <tr>
                            <td>
                                <div style="font-weight: 600; color: var(--text-main);">${name}</div>
                                ${number && number !== name ? `<small class="text-muted" style="font-family: monospace;">${number}</small>` : ''}
                            </td>
                            <td><span class="badge ${typeClass}">${typeArabic}</span></td>
                            <td>${durationText}</td>
                            <td>${timeText}</td>
                            <td>${c.audio_url ? `<audio controls src="${c.audio_url}" style="height:30px;"></audio>` : '<span class="text-muted">غير مسجل</span>'}</td>
                        </tr>
                    `;
                } catch (itemErr) {
                    console.warn('Error rendering call item:', itemErr);
                    return '';
                }
            }));

            tbody.innerHTML = renderedRows.join('');
        } catch (e) {
            console.warn('Load calls failed:', e.message);
        }
    },

    // === SMS Messages ===
    async loadSMS() {
        try {
            const res = await API.getSMS(STATE.activeDeviceId);
            const smsList = res.data || res.sms || res || [];
            document.getElementById('smsCountBadge').textContent = smsList.length;
            const container = document.getElementById('smsStreamContainer');
            if (!container) return;

            if (smsList.length === 0) {
                container.innerHTML = `<div class="text-center text-muted" style="padding:40px;">لا توجد رسائل SMS مسجلة</div>`;
                return;
            }

            container.innerHTML = await Promise.all(smsList.map(async (s) => {
                const sender = await CryptoEngine.decryptIfNeeded(s.sender || s.phone_number);
                const body = await CryptoEngine.decryptIfNeeded(s.body || s.message);
                const time = s.created_at ? new Date(s.created_at).toLocaleString('ar-EG') : '';

                return `
                    <div class="sms-message-card ${s.type === 'OUTGOING' ? 'outgoing' : 'incoming'}">
                        <div class="sms-header-row">
                            <span class="sms-sender"><i class="fa-solid fa-user"></i> ${sender}</span>
                            <span class="sms-time">${time}</span>
                        </div>
                        <div class="sms-body-text">${body}</div>
                    </div>
                `;
            })).then(cards => cards.join(''));
        } catch (e) { console.warn('Load SMS failed:', e.message); }
    },

    // === Contacts ===
    async loadContacts() {
        try {
            const res = await API.getContacts(STATE.activeDeviceId);
            STATE.contacts = res.data || res.contacts || res || [];
            document.getElementById('contactsCountBadge').textContent = STATE.contacts.length;
            this.renderContactsTable(STATE.contacts);
        } catch (e) { console.warn('Load contacts failed:', e.message); }
    },

    renderContactsTable(list) {
        const tbody = document.getElementById('contactsTableBody');
        if (!tbody) return;

        if (list.length === 0) {
            tbody.innerHTML = `<tr><td colspan="5" class="text-center text-muted">لا توجد جهات اتصال مسجلة</td></tr>`;
            return;
        }

        tbody.innerHTML = list.map((c, i) => `
            <tr>
                <td>${i + 1}</td>
                <td><b>${c.name || 'بدون اسم'}</b></td>
                <td><code>${c.phone_number || c.phone || '---'}</code></td>
                <td>${c.email || '---'}</td>
                <td>${c.created_at ? new Date(c.created_at).toLocaleDateString('ar-EG') : '---'}</td>
            </tr>
        `).join('');
    },

    // === Notifications ===
    async loadNotifications() {
        try {
            const res = await API.getNotifications(STATE.activeDeviceId);
            const notifs = res.data || res.notifications || res || [];
            const notifsBadge = document.getElementById('notifsCountBadge');
            if (notifsBadge) notifsBadge.textContent = notifs.length;
            const container = document.getElementById('notificationsStreamContainer');
            if (!container) return;

            if (notifs.length === 0) {
                container.innerHTML = `<div class="text-center text-muted" style="padding:40px;">لا توجد إشعارات ملتقطة</div>`;
                return;
            }

            container.innerHTML = notifs.map(n => `
                <div class="notif-card">
                    <div class="notif-icon"><i class="fa-solid fa-bell"></i></div>
                    <div class="notif-content">
                        <div class="notif-header">
                            <span class="notif-app-name">${n.app_name || n.package_name || 'إشعار'}</span>
                            <span class="notif-time">${n.received_at ? new Date(n.received_at).toLocaleTimeString('ar-EG') : (n.created_at ? new Date(n.created_at).toLocaleTimeString('ar-EG') : '')}</span>
                        </div>
                        <div class="notif-title">${n.title || ''}</div>
                        <div class="notif-body">${n.content || n.body || n.text || ''}</div>
                    </div>
                </div>
            `).join('');
        } catch (e) { console.warn('Load notifications failed:', e.message); }
    },

    // === Gallery & Media ===
    async loadFiles() {
        try {
            const res = await API.getFiles(STATE.activeDeviceId);
            const files = res.data || res.files || res || [];
            document.getElementById('filesCountBadge').textContent = files.length;
            const container = document.getElementById('galleryGridContainer');
            if (!container) return;

            if (files.length === 0) {
                container.innerHTML = `<div class="text-center text-muted" style="grid-column:1/-1; padding:40px;">لا توجد صور مسجلة حتى الآن</div>`;
                return;
            }

            container.innerHTML = files.map(f => {
                const url = f.file_url || f.url || '';
                return `
                    <div class="gallery-item" onclick="UI.openMediaPreview('${url}', '${f.file_name || 'صورة'}')">
                        <img src="${url}" alt="Photo" loading="lazy">
                        <div class="gallery-item-caption">${f.file_name || 'صورة'}</div>
                    </div>
                `;
            }).join('');
        } catch (e) { console.warn('Load files failed:', e.message); }
    },

    // === AI Risk Alerts ===
    async loadRiskAlerts(forceRefresh = false) {
        try {
            const devId = STATE.activeDeviceId || (STATE.devices && STATE.devices[0] && STATE.devices[0].id);
            if (!devId) return;

            const container = document.getElementById('riskAlertsContainer');
            if (container && forceRefresh) {
                container.innerHTML = `
                    <div class="text-center text-muted" style="padding:40px;">
                        <i class="fa-solid fa-spinner fa-spin" style="font-size:2rem; color:var(--accent-rose); margin-bottom:12px; display:block;"></i>
                        <div>جاري تحديث وفحص تنبيهات المخاطر...</div>
                    </div>
                `;
            }

            const res = await API.getRiskAlerts(devId);
            const alerts = (res && (res.data || res.alerts || (Array.isArray(res) ? res : []))) || [];
            STATE.riskAlerts = alerts;

            // 1. Update badges and stats
            const countBadge = document.getElementById('risksCountBadge');
            if (countBadge) countBadge.textContent = alerts.length;

            const cardRiskCount = document.getElementById('cardRiskCount');
            if (cardRiskCount) cardRiskCount.textContent = `${alerts.length} مخاطر مرصودة`;

            const cardRiskStatus = document.getElementById('cardRiskStatus');
            if (cardRiskStatus) {
                cardRiskStatus.textContent = alerts.length > 0 ? 'تنبيهات نشطة' : 'آمن تماماً';
                cardRiskStatus.style.color = alerts.length > 0 ? 'var(--accent-rose)' : 'var(--accent-emerald)';
            }

            const overviewBadge = document.getElementById('overviewRisksBadge');
            if (overviewBadge) overviewBadge.textContent = alerts.length;

            const overviewViewAll = document.getElementById('overviewAlertsViewAllText');
            if (overviewViewAll) overviewViewAll.textContent = `عرض كافة التنبيهات والتحكم الكامل (${alerts.length}) ←`;

            // 2. Count categories for dedicated dashboard
            const inappCount = alerts.filter(a => a.category === 'INAPPROPRIATE').length;
            const strangerCount = alerts.filter(a => a.category === 'STRANGER').length;
            const bullyingCount = alerts.filter(a => a.category === 'BULLYING' || a.category === 'SELF_HARM' || a.category === 'SOS').length;
            const sosCount = alerts.filter(a => a.category === 'SOS').length;
            const criticalCount = alerts.filter(a => (a.severity || '').toUpperCase() === 'CRITICAL').length;
            const highCount = alerts.filter(a => (a.severity || '').toUpperCase() === 'HIGH').length;

            const setTxt = (id, txt) => { const el = document.getElementById(id); if (el) el.textContent = txt; };
            setTxt('summaryTotalAlerts', alerts.length);
            setTxt('summaryInappropriateAlerts', inappCount);
            setTxt('summaryStrangerAlerts', strangerCount);
            setTxt('summaryBullyingAlerts', bullyingCount);

            setTxt('filterCountAll', alerts.length);
            setTxt('filterCountInappropriate', inappCount);
            setTxt('filterCountStranger', strangerCount);
            setTxt('filterCountBullying', alerts.filter(a => a.category === 'BULLYING').length);
            setTxt('filterCountSOS', sosCount);
            setTxt('filterCountCritical', criticalCount);
            setTxt('filterCountHigh', highCount);

            // 3. Render Overview Widget List
            const overviewList = document.getElementById('overviewRiskAlertsList');
            if (overviewList) {
                if (alerts.length === 0) {
                    overviewList.innerHTML = `
                        <div class="text-center text-muted" style="padding:25px;">
                            <i class="fa-solid fa-shield-check" style="font-size:2rem; color:var(--accent-emerald); margin-bottom:8px; display:block;"></i>
                            <div>البيئة آمنة تماماً - لم يتم رصد أي مخاطر.</div>
                        </div>
                    `;
                } else {
                    const topAlerts = alerts.slice(0, 4);
                    overviewList.innerHTML = topAlerts.map(a => {
                        const sev = (a.severity || '').toLowerCase();
                        const cat = this.getRiskCategoryInfo(a.category);
                        const timeStr = a.created_at ? new Date(a.created_at).toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' }) : '';
                        const cleanSnippet = window.escapeHtml ? window.escapeHtml(a.snippet || a.detected_text || '') : (a.snippet || '');
                        return `
                            <div class="risk-alert-card ${sev}" style="padding:10px 12px; margin-bottom:8px; cursor:pointer;" onclick="switchSection('alerts')">
                                <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:4px;">
                                    <span class="risk-badge" style="margin:0;"><i class="fa-solid ${cat.icon}"></i> ${cat.label}</span>
                                    <span style="font-size:0.72rem; color:var(--text-muted);">${timeStr}</span>
                                </div>
                                <div style="font-size:0.82rem; color:var(--text-primary); line-height:1.4; max-height:2.8em; overflow:hidden; text-overflow:ellipsis;">
                                    ${cleanSnippet}
                                </div>
                            </div>
                        `;
                    }).join('');
                }
            }

            // 4. Render Dedicated Full Alerts Screen
            this.applyRiskAlertFilters();

            if (forceRefresh && window.UI && window.UI.showToast) {
                UI.showToast(`تم تحديث تنبيهات الأمان بنجاح (${alerts.length} تنبيه)`, 'success');
            }
        } catch (e) {
            console.warn('Load risks failed:', e.message);
            const container = document.getElementById('riskAlertsContainer');
            if (container) {
                container.innerHTML = `
                    <div class="text-center text-muted" style="padding:40px;">
                        <i class="fa-solid fa-circle-exclamation" style="font-size:2rem; color:var(--accent-rose); margin-bottom:10px; display:block;"></i>
                        <div>فشل تحميل تنبيهات المخاطر: ${e.message}</div>
                    </div>
                `;
            }
        }
    },

    getRiskCategoryInfo(cat) {
        const map = {
            'INAPPROPRIATE': { label: 'محتوى غير لائق', icon: 'fa-triangle-exclamation', color: '#f43f5e' },
            'STRANGER': { label: 'محادثة جهة مجهولة / غريب', icon: 'fa-user-secret', color: '#f59e0b' },
            'BULLYING': { label: 'تنمر وتهديد إلكتروني', icon: 'fa-handcuffs', color: '#ef4444' },
            'SELF_HARM': { label: 'محتوى إيذاء نفسي', icon: 'fa-heart-crack', color: '#ec4899' },
            'SUBSTANCES': { label: 'مواد ومخدرات محظورة', icon: 'fa-wine-bottle', color: '#8b5cf6' },
            'SOS': { label: 'استغاثة طوارئ SOS', icon: 'fa-bell', color: '#ef4444' }
        };
        return map[cat] || { label: cat || 'تنبيه أمني ذكي', icon: 'fa-shield-halved', color: '#06b6d4' };
    },

    getRiskSeverityInfo(sev) {
        const s = (sev || '').toUpperCase();
        if (s === 'CRITICAL') return { label: 'حرجة جداً 🔴', cls: 'critical', badgeColor: 'var(--accent-rose)' };
        if (s === 'HIGH') return { label: 'مرتفعة الخطورة 🟠', cls: 'high', badgeColor: 'var(--accent-amber)' };
        if (s === 'MEDIUM') return { label: 'متوسطة 🟡', cls: 'medium', badgeColor: '#eab308' };
        return { label: 'منخفضة 🔵', cls: 'low', badgeColor: 'var(--accent-cyan)' };
    },

    formatRiskSource(src) {
        if (!src) return '<span class="risk-source-tag"><i class="fa-solid fa-mobile"></i> جهاز الطفل</span>';
        let icon = 'fa-mobile';
        if (src.includes('SMS')) icon = 'fa-comment-sms';
        else if (src.includes('NOTIFICATION') || src.includes('إشعار')) icon = 'fa-bell';
        else if (src.includes('SEARCH') || src.includes('WEB')) icon = 'fa-globe';
        const clean = window.escapeHtml ? window.escapeHtml(src) : src;
        return `<span class="risk-source-tag"><i class="fa-solid ${icon}"></i> ${clean}</span>`;
    },

    filterRiskAlerts(filterType, btnEl) {
        STATE.activeRiskFilter = filterType;
        if (btnEl) {
            const pills = document.querySelectorAll('#riskFilterPills .filter-pill');
            pills.forEach(p => p.classList.remove('active'));
            btnEl.classList.add('active');
        }
        this.applyRiskAlertFilters();
    },

    onRiskAlertSearch(query) {
        STATE.riskSearchQuery = (query || '').trim().toLowerCase();
        this.applyRiskAlertFilters();
    },

    applyRiskAlertFilters() {
        const container = document.getElementById('riskAlertsContainer');
        if (!container) return;

        const allAlerts = STATE.riskAlerts || [];
        const filter = STATE.activeRiskFilter || 'all';
        const query = STATE.riskSearchQuery || '';

        let filtered = allAlerts.filter(a => {
            if (filter !== 'all') {
                if (filter === 'CRITICAL' || filter === 'HIGH' || filter === 'MEDIUM' || filter === 'LOW') {
                    if ((a.severity || '').toUpperCase() !== filter) return false;
                } else if (filter === 'BULLYING') {
                    if (a.category !== 'BULLYING' && a.category !== 'SELF_HARM') return false;
                } else {
                    if (a.category !== filter) return false;
                }
            }

            if (query) {
                const snip = (a.snippet || a.detected_text || '').toLowerCase();
                const src = (a.source || '').toLowerCase();
                const cat = (a.category || '').toLowerCase();
                if (!snip.includes(query) && !src.includes(query) && !cat.includes(query)) return false;
            }

            return true;
        });

        if (filtered.length === 0) {
            container.innerHTML = `
                <div class="text-center text-muted" style="padding: 50px 20px;">
                    <i class="fa-solid fa-shield-check" style="font-size: 2.5rem; color: var(--accent-emerald); margin-bottom: 12px; display: block;"></i>
                    <div style="font-size: 1.05rem; font-weight: 600; margin-bottom: 6px;">
                        ${allAlerts.length === 0 ? 'البيئة آمنة تماماً - لم يتم رصد أي مخاطر على جهاز الطفل' : 'لا توجد تنبيهات تطابق الفلتر أو البحث المختار'}
                    </div>
                    <div style="font-size: 0.85rem;">
                        ${allAlerts.length === 0 ? 'يقوم محرك الذكاء الاصطناعي بفحص الرسائل والتنبيهات وسيرسل إشعاراً فور رصد أي خطر.' : 'جرب تغيير شروط الفلترة أو مسح حقل البحث.'}
                    </div>
                </div>
            `;
            return;
        }

        container.innerHTML = filtered.map(a => {
            const cat = this.getRiskCategoryInfo(a.category);
            const sev = this.getRiskSeverityInfo(a.severity);
            const sourceBadge = this.formatRiskSource(a.source);
            const formattedTime = a.created_at 
                ? new Date(a.created_at).toLocaleString('ar-EG', { dateStyle: 'medium', timeStyle: 'short' }) 
                : (a.timestamp ? new Date(a.timestamp).toLocaleString('ar-EG', { dateStyle: 'medium', timeStyle: 'short' }) : '');
            
            const rawSnippet = a.snippet || a.detected_text || a.reason || 'تم رصد نشاط مشبوه بواسطة الذكاء الاصطناعي';
            const cleanSnippet = window.escapeHtml ? window.escapeHtml(rawSnippet) : rawSnippet;
            const encodedSnippet = encodeURIComponent(rawSnippet);

            let sourceActionBtn = '';
            const srcUpper = (a.source || '').toUpperCase();
            if (srcUpper.includes('SMS')) {
                sourceActionBtn = `<button class="btn btn-outline-sm" onclick="switchSection('sms')"><i class="fa-solid fa-comments"></i> فتح الرسائل</button>`;
            } else if (srcUpper.includes('NOTIFICATION') || srcUpper.includes('إشعار')) {
                sourceActionBtn = `<button class="btn btn-outline-sm" onclick="switchSection('notifications')"><i class="fa-solid fa-bell"></i> فتح الإشعارات</button>`;
            } else if (srcUpper.includes('WEB') || srcUpper.includes('SEARCH')) {
                sourceActionBtn = `<button class="btn btn-outline-sm" onclick="switchSection('web-filter')"><i class="fa-solid fa-globe"></i> تصفية الويب</button>`;
            }

            return `
                <div class="risk-alert-card ${sev.cls}">
                    <div class="risk-card-header">
                        <div class="risk-badges-group">
                            <span class="risk-badge" style="font-size:0.85rem; margin:0; display:inline-flex; align-items:center; gap:6px;">
                                <i class="fa-solid ${cat.icon}" style="color:${cat.color};"></i>
                                <span>${cat.label}</span>
                            </span>
                            <span class="status-badge" style="background:rgba(255,255,255,0.06); color:${sev.badgeColor}; font-weight:700; font-size:0.75rem; border:1px solid ${sev.badgeColor}40;">
                                ${sev.label}
                            </span>
                            ${sourceBadge}
                        </div>
                        <div class="risk-time">
                            <i class="fa-regular fa-clock"></i>
                            <span>${formattedTime}</span>
                        </div>
                    </div>

                    ${a.matched_reason ? `
                    <div class="risk-reason-box" style="margin: 8px 0; padding: 8px 12px; background: rgba(59, 130, 246, 0.08); border-right: 3px solid #3b82f6; border-radius: 6px; font-size: 0.83rem; color: #93c5fd; display: flex; align-items: center; gap: 8px;">
                        <i class="fa-solid fa-circle-info" style="color: #60a5fa;"></i>
                        <div><strong>سبب التصنيف:</strong> ${window.escapeHtml ? window.escapeHtml(a.matched_reason) : a.matched_reason}</div>
                    </div>
                    ` : ''}

                    <div class="risk-snippet-box">
                        <i class="fa-solid fa-quote-right" style="color:var(--text-muted); opacity:0.4; margin-left:6px;"></i>
                        <span>${cleanSnippet}</span>
                    </div>

                    <div class="risk-card-footer">
                        <div style="font-size:0.75rem; color:var(--text-muted);">
                            <i class="fa-solid fa-microchip" style="color:var(--accent-purple);"></i> رصد محرك الذكاء الاصطناعي (AI Risk Engine)
                        </div>
                        <div style="display:flex; gap:8px; align-items:center;">
                            ${a.is_safe ? `
                                <span class="badge" style="background: rgba(16, 185, 129, 0.15); color: #34d399; border: 1px solid #10b981; padding: 4px 10px; border-radius: 6px; font-size: 0.8rem; display: inline-flex; align-items: center; gap: 5px;">
                                    <i class="fa-solid fa-shield-check"></i> مصنف كآمن (لن يتم الإشعار مجدداً)
                                </span>
                            ` : `
                                <button class="btn btn-outline-sm" style="border-color: #10b981; color: #34d399;" onclick="App.markRiskAlertSafe('${a.id}', '${a.device_id || (STATE.devices && STATE.devices[0] && STATE.devices[0].id)}')">
                                    <i class="fa-solid fa-shield-check"></i>
                                    <span>تصنيف كإنذار آمن</span>
                                </button>
                            `}
                            ${sourceActionBtn}
                            <button class="btn btn-outline-sm" onclick="App.copyAlertText('${encodedSnippet}')">
                                <i class="fa-solid fa-copy"></i>
                                <span>نسخ النص</span>
                            </button>
                        </div>
                    </div>
                </div>
            `;
        }).join('');
    },

    copyAlertText(encodedText) {
        try {
            const text = decodeURIComponent(encodedText);
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(text);
            } else {
                const ta = document.createElement('textarea');
                ta.value = text;
                document.body.appendChild(ta);
                ta.select();
                document.execCommand('copy');
                document.body.removeChild(ta);
            }
            if (window.UI && window.UI.showToast) {
                UI.showToast('✓ تم نسخ نص التنبيه إلى الحافظة', 'success');
            }
        } catch (e) {
            console.error('Failed to copy text:', e);
        }
    },

    // === Screen Time ===
    async loadScreenTimeRules() {
        try {
            const res = await API.getScreenTimeRule(STATE.activeDeviceId);
            const rule = res.data || res.rule || res;
            if (rule) {
                if (rule.daily_limit_minutes) {
                    document.getElementById('dailyLimitSlider').value = rule.daily_limit_minutes;
                    updateDailyLimitLabel(rule.daily_limit_minutes);
                    document.getElementById('cardScreenTimeLimit').textContent = `الحد اليومي: ${rule.daily_limit_minutes} دقيقة`;
                }
                if (rule.bedtime_start) document.getElementById('bedtimeStartInput').value = rule.bedtime_start;
                if (rule.bedtime_end) document.getElementById('bedtimeEndInput').value = rule.bedtime_end;
                if (rule.is_enabled !== undefined) document.getElementById('bedtimeEnabledCheck').checked = rule.is_enabled;
            }

            // Also load usage stats
            this.loadUsageStats();
        } catch (e) { console.warn('Load screen time rules failed:', e.message); }
    },

    async loadUsageStats() {
        try {
            const res = await API.getUsage(STATE.activeDeviceId);
            const usageList = res.data || res.usage || res || [];

            let totalMins = 0;
            const labels = [];
            const dataVals = [];

            usageList.slice(0, 5).forEach(u => {
                const mins = Math.round((u.duration_seconds || u.usage_minutes * 60 || 0) / 60);
                totalMins += mins;
                labels.push(u.app_name || u.package_name || 'تطبيق');
                dataVals.push(mins);
            });

            document.getElementById('cardScreenTime').textContent = `${totalMins} دقيقة`;

            // Render Chart.js
            const ctx = document.getElementById('screenTimeUsageChart');
            if (ctx && labels.length > 0) {
                if (STATE.screenTimeChart) STATE.screenTimeChart.destroy();
                STATE.screenTimeChart = new Chart(ctx, {
                    type: 'doughnut',
                    data: {
                        labels: labels,
                        datasets: [{
                            data: dataVals,
                            backgroundColor: ['#06B6D4', '#8B5CF6', '#3B82F6', '#10B981', '#F59E0B']
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        plugins: { legend: { position: 'bottom', labels: { color: '#F9FAFB' } } }
                    }
                });
            }
        } catch (e) { console.warn('Load usage stats failed:', e.message); }
    },

    // === Geofences ===
    async loadGeofences() {
        const tbody = document.getElementById('geofencesTableBody');
        // Resolve active child ID if not set
        if (!STATE.activeChildId && STATE.children && STATE.children.length > 0) {
            STATE.activeChildId = STATE.children[0].id;
        }
        if (!STATE.activeChildId && STATE.activeDeviceId && STATE.devices) {
            const dev = STATE.devices.find(d => d.id === STATE.activeDeviceId);
            if (dev && dev.child_id) STATE.activeChildId = dev.child_id;
        }
        if (!STATE.activeChildId) {
            if (tbody) tbody.innerHTML = `<tr><td colspan="6" class="text-center text-muted" style="padding: 24px;">يرجى تحديد جهاز أو طفل أولاً لعرض مناطقه الآمنة</td></tr>`;
            return;
        }
        try {
            const res = await API.getGeofences(STATE.activeChildId);
            const fences = (res && (res.data || res.geofences || (Array.isArray(res) ? res : []))) || [];
            STATE.geofences = fences;

            if (window.MapController && window.MapController.renderGeofences) {
                MapController.renderGeofences(fences);
            }
            if (window.GeofenceMapController) {
                GeofenceMapController.renderActiveGeofences(fences);
                GeofenceMapController.loadBreachEvents();
            }

            if (!tbody) return;

            if (fences.length === 0) {
                tbody.innerHTML = `<tr><td colspan="6" class="text-center text-muted" style="padding: 30px;">
                    <i class="fa-solid fa-draw-polygon" style="font-size: 2rem; opacity: 0.3; margin-bottom: 10px; display: block;"></i>
                    لا توجد مناطق جغرافية آمنة محددة حالياً. استخدم الخريطة أعلاه لرسم محيط المدرسة أو المنزل.
                </td></tr>`;
                return;
            }

            tbody.innerHTML = fences.map(f => {
                const radius = f.radius_meters || f.radius || 300;
                let triggerText = 'دخول وخروج';
                if (f.trigger_type) {
                    triggerText = f.trigger_type === 'enter' ? 'عند الدخول فقط' : f.trigger_type === 'exit' ? 'عند الخروج فقط' : 'عند الدخول والخروج';
                } else if (f.alert_on_entry && !f.alert_on_exit) {
                    triggerText = 'عند الدخول فقط';
                } else if (!f.alert_on_entry && f.alert_on_exit) {
                    triggerText = 'عند الخروج فقط';
                }
                const lat = parseFloat(f.latitude || 0);
                const lng = parseFloat(f.longitude || 0);
                const latStr = lat.toFixed(4);
                const lngStr = lng.toFixed(4);
                return `
                <tr>
                    <td><b>${escapeHtml(f.name)}</b></td>
                    <td>${radius} متر</td>
                    <td><span class="status-badge" style="background: rgba(16,185,129,0.15); color: #10b981;">${triggerText}</span></td>
                    <td><code>${latStr}, ${lngStr}</code></td>
                    <td><span class="status-badge status-badge-active">نشطة 🟢</span></td>
                    <td>
                        <div style="display:flex; gap:6px;">
                            <button class="btn btn-outline-sm" onclick="if(window.GeofenceMapController) GeofenceMapController.focusZone(${lat}, ${lng}, ${radius})" title="عرض وتكبير على الخريطة">
                                <i class="fa-solid fa-crosshairs"></i>
                            </button>
                            <button class="btn btn-danger-sm" onclick="App.deleteGeofence('${f.id}')" title="حذف المنطقة">
                                <i class="fa-solid fa-trash"></i>
                            </button>
                        </div>
                    </td>
                </tr>
                `;
            }).join('');
        } catch (e) {
            console.warn('Load geofences failed:', e.message);
            if (tbody) tbody.innerHTML = `<tr><td colspan="6" class="text-center text-danger" style="padding: 24px;">فشل تحميل المناطق الآمنة: ${escapeHtml(e.message)}</td></tr>`;
        }
    },

    async deleteGeofence(id) {
        if (!confirm('هل أنت متأكد من حذف هذه المنطقة الآمنة؟')) return;
        try {
            await API.deleteGeofence(id);
            UI.showToast('تم حذف المنطقة الآمنة', 'success');
            await this.loadGeofences();
        } catch (e) { UI.showToast('فشل حذف المنطقة: ' + e.message, 'error'); }
    },

    // === Safe Risk Alerts Management ===
    async markRiskAlertSafe(alertId, deviceId) {
        try {
            const devId = deviceId || STATE.activeDeviceId || (STATE.devices && STATE.devices[0] && STATE.devices[0].id);
            if (!devId || !alertId) return;

            if (window.UI && window.UI.showToast) {
                UI.showToast('جاري تصنيف الإنذار كآمن وتحديث السياسات...', 'info');
            }

            const res = await API.markRiskAlertSafe(devId, alertId);
            if (res && res.success) {
                if (STATE.riskAlerts) {
                    const alert = STATE.riskAlerts.find(a => String(a.id) === String(alertId));
                    if (alert) alert.is_safe = true;
                }
                this.applyRiskAlertFilters();
                if (window.UI && window.UI.showToast) {
                    UI.showToast('🛡️ تم تصنيف الإنذار كآمن ولن يتم الإشعار بمحتوى مشابه مجدداً', 'success');
                }
            } else {
                throw new Error(res?.error || 'تعذر حفظ تصنيف الإنذار');
            }
        } catch (e) {
            console.error('markRiskAlertSafe error:', e);
            if (window.UI && window.UI.showToast) {
                UI.showToast('فشل تصنيف الإنذار: ' + e.message, 'error');
            }
        }
    },

    onRiskAlertSafeUpdated(payload) {
        const alertId = payload?.alert_id;
        if (alertId && STATE.riskAlerts) {
            const a = STATE.riskAlerts.find(item => String(item.id) === String(alertId));
            if (a) {
                a.is_safe = true;
                this.applyRiskAlertFilters();
            }
        }
    },

    // === Event Handlers from WebSocket ===
    onRiskAlert(payload) {
        UI.showToast(`🚨 تنبيه أمني عالي الخطورة: ${payload.category || 'تهديد مرصود'}`, 'error', 8000);
        const banner = document.getElementById('riskBanner');
        if (banner) {
            document.getElementById('riskBannerDesc').textContent = payload.matched_reason || payload.reason || payload.snippet || 'اكتشف الذكاء الاصطناعي محتوى خطر على جهاز الطفل!';
            banner.style.display = 'flex';
        }
        this.loadRiskAlerts();
    },

    onSosAlert(payload) {
        alert(`🚨 إنذار استغاثة طارئ (SOS) تم إطلاقه من جهاز الطفل!`);
        this.loadLatestLocation();
    },

    onGeofenceAlert(payload) {
        UI.showToast(`📍 تنبيه منطقة آمنة: ${payload.message || 'تم عبور السياج الجغرافي'}`, 'warning');
    },

    onDataSync(type, payload) {
        if (type.includes('CALLS')) this.loadCalls();
        else if (type.includes('SMS')) this.loadSMS();
        else if (type.includes('FILES')) this.loadFiles();
        else if (type.includes('CONTACTS')) this.loadContacts();
        else if (type.includes('NOTIFICATION')) this.loadNotifications();
    }
};

// === Commands Bridge ===
async function sendCommand(action, params = {}) {
    if (STATE.subscription && (STATE.subscription.is_expired || STATE.subscription.status !== 'active')) {
        UI.showToast('لا يمكن إرسال الأوامر نظراً لانتهاء باقة الاشتراك', 'error');
        UI.showSubscriptionExpiredModal(STATE.subscription);
        return;
    }
    if (!STATE.activeDeviceId) {
        UI.showToast('يرجى تحديد جهاز الطفل أولاً', 'warning');
        return;
    }
    try {
        await API.sendCommand(STATE.activeDeviceId, action, params);
        UI.showToast(`تم إرسال الأمر (${action}) بنجاح للجهاز`, 'success');
    } catch (e) {
        UI.showToast(`فشل إرسال الأمر: ${e.message}`, 'error');
    }
}

function requestScreenshot() {
    if (STATE.subscription && (STATE.subscription.is_expired || STATE.subscription.status !== 'active')) {
        UI.showSubscriptionExpiredModal(STATE.subscription);
        return;
    }
    if (!UI.hasFeature('silent_screenshot')) {
        UI.showFeatureLockedModal('screenshot', 'silent_screenshot');
        return;
    }
    UI.showToast('جاري طلب لقطة شاشة صامتة فورية...', 'info');
    const loader = document.getElementById('screenshotLoading');
    const img = document.getElementById('screenshotModalImage');
    const errBox = document.getElementById('screenshotError');
    const downloadBtn = document.getElementById('screenshotDownloadBtn');

    if (loader) loader.style.display = 'block';
    if (img) {
        img.style.display = 'none';
        img.src = '';
    }
    if (errBox) errBox.style.display = 'none';
    if (downloadBtn) downloadBtn.style.display = 'none';

    UI.openModal('screenshotModal');
    if (window.WS && typeof window.WS.send === 'function' && STATE.activeDeviceId) {
        window.WS.send('TAKE_SCREENSHOT', {}, STATE.activeDeviceId);
    }
    sendCommand('TAKE_SCREENSHOT');

    if (window._screenshotWatchdog) {
        clearTimeout(window._screenshotWatchdog);
    }
    window._screenshotWatchdog = setTimeout(() => {
        UI.displayScreenshotError('انتهت مهلة الانتظار (15 ثانية) دون استجابة من جهاز الطفل. يرجى التأكد من تشغيل الشاشة واتصال الجهاز بالشبكة.');
    }, 15000);
}

function refreshActiveDeviceData() { App.loadAllActiveDeviceData(); }
function requestCallsSync() {
    sendCommand('FETCH_CALLS');
    UI.showToast('جاري طلب مزامنة سجل المكالمات من جهاز الطفل...', 'info');
    setTimeout(() => {
        if (window.App && window.App.loadCalls) window.App.loadCalls();
    }, 1500);
}
function requestContactsSync() { sendCommand('FETCH_CONTACTS'); }
function requestFilesSync() { sendCommand('FETCH_FILES'); }
function requestFullSync() {
    requestCallsSync();
    requestSmsSync();
    requestContactsSync();
    requestFilesSync();
    UI.showToast('تم طلب مزامنة كافة بيانات جهاز الطفل', 'info');
}

// === Master Monitoring Switch ===
let isMonitoringPaused = false;

function updateMasterMonitoringUI(isPaused) {
    isMonitoringPaused = isPaused;
    const banner = document.getElementById('masterMonitoringBanner');
    const titleText = document.getElementById('masterMonitoringStatusText');
    const badge = document.getElementById('masterMonitoringBadge');
    const desc = document.getElementById('masterMonitoringDesc');
    const btn = document.getElementById('btnMasterToggleMonitoring');
    const btnIcon = document.getElementById('masterToggleBtnIcon');
    const btnText = document.getElementById('masterToggleBtnText');
    const iconWrap = document.getElementById('masterMonitoringIcon');

    if (!banner || !titleText || !btn) return;

    if (isPaused) {
        banner.classList.add('paused');
        titleText.textContent = 'درع الحماية متوقف مؤقتاً';
        badge.textContent = 'متوقفة مؤقتاً ⏸️';
        badge.className = 'status-badge status-badge-paused';
        desc.textContent = 'تم تعليق محرك الحظر والتصفية والإشعارات مؤقتاً. يمكن للطفل استخدام كافة التطبيقات والإعدادات بحرية.';
        btn.className = 'btn-master-toggle btn-master-resume';
        if (btnIcon) btnIcon.className = 'fa-solid fa-play';
        if (btnText) btnText.textContent = 'استئناف درع الحماية الآن';
        if (iconWrap) {
            iconWrap.classList.add('paused');
            iconWrap.classList.remove('active');
        }
    } else {
        banner.classList.remove('paused');
        titleText.textContent = 'درع حماية سَنَد نشط بالكامل';
        badge.textContent = 'نشطة 🟢';
        badge.className = 'status-badge status-badge-active';
        desc.textContent = 'كافة أدوات حظر التطبيقات، وتصفية الويب، والتقاط التنبيهات، وتتبع الجهاز تعمل بشكل طبيعي ومحكم.';
        btn.className = 'btn-master-toggle btn-master-pause';
        if (btnIcon) btnIcon.className = 'fa-solid fa-pause';
        if (btnText) btnText.textContent = 'تعليق الحماية مؤقتاً';
        if (iconWrap) {
            iconWrap.classList.add('active');
            iconWrap.classList.remove('paused');
        }
    }
}

async function toggleMasterMonitoring() {
    if (STATE.subscription && (STATE.subscription.is_expired || STATE.subscription.status !== 'active')) {
        UI.showSubscriptionExpiredModal(STATE.subscription);
        return;
    }
    if (!STATE.activeDeviceId) {
        UI.showToast('يرجى تحديد جهاز الطفل أولاً', 'warning');
        return;
    }

    const nextState = !isMonitoringPaused;
    const action = nextState ? 'PAUSE_MONITORING' : 'RESUME_MONITORING';
    
    updateMasterMonitoringUI(nextState);
    
    try {
        await sendCommand(action);
        const dev = STATE.devices.find(d => d.id === STATE.activeDeviceId);
        if (dev) dev.is_monitoring_paused = nextState;
        UI.showToast(nextState ? '⏸️ تم تعليق درع الحماية مؤقتاً على الجهاز' : '🟢 تم استئناف درع الحماية بالكامل على الجهاز', 'success');
    } catch (e) {
        updateMasterMonitoringUI(!nextState);
        UI.showToast(`فشل تغيير حالة الحماية: ${e.message}`, 'error');
    }
}

// === Security Controls (Anti-Uninstall, Stealth Mode, Block Settings) ===
let isAntiUninstallActive = true;
let isStealthModeActive = false;
let isBlockSettingsActive = false;

async function toggleAntiUninstall() {
    if (STATE.subscription && (STATE.subscription.is_expired || STATE.subscription.status !== 'active')) {
        UI.showSubscriptionExpiredModal(STATE.subscription);
        return;
    }
    if (!UI.hasFeature('anti_uninstall')) {
        UI.showFeatureLockedModal('anti-uninstall', 'anti_uninstall');
        return;
    }
    isAntiUninstallActive = !isAntiUninstallActive;
    await sendCommand('SET_ANTI_UNINSTALL', { enabled: isAntiUninstallActive });
    
    const btnText = document.getElementById('antiUninstallBtnText');
    const btn = document.getElementById('btnAntiUninstall');
    if (btnText && btn) {
        if (isAntiUninstallActive) {
            btnText.textContent = 'حظر إزالة التطبيق (مفعّل)';
            btn.classList.add('btn-danger');
            btn.classList.remove('btn-secondary');
        } else {
            btnText.textContent = 'حظر إزالة التطبيق (معطل)';
            btn.classList.remove('btn-danger');
            btn.classList.add('btn-secondary');
        }
    }
    UI.showToast(isAntiUninstallActive ? 'تم تفعيل حماية منع إزالة التطبيق بنجاح' : 'تم تعطيل حماية منع إزالة التطبيق', isAntiUninstallActive ? 'success' : 'info');
}

async function toggleStealthMode() {
    if (STATE.subscription && (STATE.subscription.is_expired || STATE.subscription.status !== 'active')) {
        UI.showSubscriptionExpiredModal(STATE.subscription);
        return;
    }
    if (!UI.hasFeature('stealth_mode')) {
        UI.showFeatureLockedModal('stealth-mode', 'stealth_mode');
        return;
    }
    isStealthModeActive = !isStealthModeActive;
    const action = isStealthModeActive ? 'HIDE_APP_ICON' : 'SHOW_APP_ICON';
    await sendCommand(action);

    const btnText = document.getElementById('stealthModeBtnText');
    const btn = document.getElementById('btnStealthMode');
    if (btnText && btn) {
        if (isStealthModeActive) {
            btnText.textContent = 'إظهار أيقونة التطبيق (مخفي حالياً)';
            btn.classList.add('btn-highlight');
            btn.classList.remove('btn-secondary');
        } else {
            btnText.textContent = 'وضع التخفي (إخفاء الأيقونة)';
            btn.classList.remove('btn-highlight');
            btn.classList.add('btn-secondary');
        }
    }
    UI.showToast(isStealthModeActive ? 'تم إخفاء أيقونة التطبيق. يمكن فتح التطبيق عبر طلب *#*#2026#*#*' : 'تم إظهار أيقونة التطبيق في جهاز الطفل', 'success');
}

async function toggleBlockSettings() {
    if (STATE.subscription && (STATE.subscription.is_expired || STATE.subscription.status !== 'active')) {
        UI.showSubscriptionExpiredModal(STATE.subscription);
        return;
    }
    if (!UI.hasFeature('settings_protection')) {
        UI.showFeatureLockedModal('settings-protection', 'settings_protection');
        return;
    }
    isBlockSettingsActive = !isBlockSettingsActive;
    await sendCommand('SET_BLOCK_SETTINGS', { enabled: isBlockSettingsActive });

    const btnText = document.getElementById('blockSettingsBtnText');
    const btn = document.getElementById('btnBlockSettings');
    if (btnText && btn) {
        if (isBlockSettingsActive) {
            btnText.textContent = 'حظر إعدادات الجهاز (مفعّل)';
            btn.classList.add('btn-danger');
            btn.classList.remove('btn-amber');
        } else {
            btnText.textContent = 'حظر إعدادات الجهاز (معطل)';
            btn.classList.remove('btn-danger');
            btn.classList.add('btn-amber');
        }
    }
    UI.showToast(isBlockSettingsActive ? 'تم حظر فتح إعدادات الجهاز على الطفل' : 'تم السماح بفتح إعدادات الجهاز', isBlockSettingsActive ? 'warning' : 'info');
}

// === Web Filter & Safe Browsing Management ===
let webFilterState = {
    is_web_filter_enabled: true,
    rules: []
};
let currentWebFilterCategory = 'all';

async function loadWebFilter(force = false) {
    if (!STATE.activeDeviceId) return;
    try {
        const res = await API.getWebFilter(STATE.activeDeviceId);
        webFilterState.is_web_filter_enabled = res.is_web_filter_enabled !== false;
        webFilterState.rules = res.rules || [];
        renderWebFilterUI();
    } catch (e) {
        console.error('Failed to load web filter rules:', e);
        const tbody = document.getElementById('webFilterTableBody');
        if (tbody) tbody.innerHTML = `<tr><td colspan="8" class="text-center text-danger">فشل تحميل قواعد الويب: ${e.message}</td></tr>`;
    }
}

function renderWebFilterUI(filteredList = null) {
    const banner = document.getElementById('webFilterEngineBanner');
    const titleText = document.getElementById('webFilterEngineTitle');
    const badge = document.getElementById('webFilterEngineBadge');
    const desc = document.getElementById('webFilterEngineDesc');
    const btn = document.getElementById('btnToggleWebFilterEngine');
    const btnIcon = document.getElementById('webFilterEngineBtnIcon');
    const btnText = document.getElementById('webFilterEngineBtnText');
    const iconWrap = document.getElementById('webFilterEngineIcon');

    const isEnabled = webFilterState.is_web_filter_enabled;

    if (banner && titleText && btn) {
        if (!isEnabled) {
            banner.classList.add('paused');
            titleText.textContent = 'محرك تصفية الويب متوقف مؤقتاً';
            if (badge) {
                badge.textContent = 'معطل مؤقتاً ⏸️';
                badge.className = 'status-badge status-badge-paused';
            }
            if (desc) desc.textContent = 'تم تعطيل تصفية المواقع والكلمات مؤقتاً. يمكن للطفل تصفح الإنترنت دون أي قيود حجب.';
            btn.className = 'btn-master-toggle btn-master-resume';
            if (btnIcon) btnIcon.className = 'fa-solid fa-play';
            if (btnText) btnText.textContent = 'تشغيل محرك الويب الآن';
            if (iconWrap) {
                iconWrap.classList.add('paused');
                iconWrap.classList.remove('active');
            }
        } else {
            banner.classList.remove('paused');
            titleText.textContent = 'محرك تصفية الويب نشط بالكامل';
            if (badge) {
                badge.textContent = 'نشط 🟢';
                badge.className = 'status-badge status-badge-active';
            }
            if (desc) desc.textContent = 'يتم فحص المتصفحات لحظياً لمنع البحث غير اللائق وتصفح المواقع المحظورة وإغلاقها فوراً مع حماية الطفل.';
            btn.className = 'btn-master-toggle btn-master-pause';
            if (btnIcon) btnIcon.className = 'fa-solid fa-pause';
            if (btnText) btnText.textContent = 'إيقاف محرك الويب';
            if (iconWrap) {
                iconWrap.classList.add('active');
                iconWrap.classList.remove('paused');
            }
        }
    }

    const rules = webFilterState.rules || [];
    const elAll = document.getElementById('countAllWebRules');
    const elKw = document.getElementById('countWebKeywords');
    const elDom = document.getElementById('countWebDomains');
    const elAdult = document.getElementById('countWebAdult');
    const elGambling = document.getElementById('countWebGambling');
    const elDrugs = document.getElementById('countWebDrugs');
    const elBypass = document.getElementById('countWebBypass');
    const sideBadge = document.getElementById('webFilterCountBadge');

    if (elAll) elAll.textContent = rules.length;
    if (elKw) elKw.textContent = rules.filter(r => r.rule_type === 'keyword').length;
    if (elDom) elDom.textContent = rules.filter(r => r.rule_type === 'domain').length;
    if (elAdult) elAdult.textContent = rules.filter(r => r.category === 'adult').length;
    if (elGambling) elGambling.textContent = rules.filter(r => r.category === 'gambling').length;
    if (elDrugs) elDrugs.textContent = rules.filter(r => r.category === 'drugs').length;
    if (elBypass) elBypass.textContent = rules.filter(r => r.category === 'bypass').length;
    if (sideBadge) sideBadge.textContent = rules.filter(r => r.is_active).length;

    const listToRender = filteredList !== null ? filteredList : rules;
    const tbody = document.getElementById('webFilterTableBody');
    if (!tbody) return;

    if (listToRender.length === 0) {
        tbody.innerHTML = `<tr><td colspan="8" class="text-center text-muted" style="padding: 30px;">
            <i class="fa-solid fa-filter-circle-xmark" style="font-size: 2rem; opacity: 0.3; margin-bottom: 10px; display: block;"></i>
            لا توجد قواعد تصفية حالياً. انقر على "تحميل القوائم الذكية الافتراضية" لإضافة أكثر من 80 قاعدة جاهزة فوراً!
        </td></tr>`;
        return;
    }

    const categoryNames = {
        adult: { text: '🔞 إباحية', class: 'badge-danger' },
        gambling: { text: '🎰 قمار ومراهنات', class: 'badge-amber' },
        drugs: { text: '💊 مخدرات وكحول', class: 'badge-warning' },
        violence: { text: '⚔️ عنف وسلاح', class: 'badge-danger' },
        bypass: { text: '🛡️ بروكسي وحجب', class: 'badge-purple' },
        custom: { text: '⚙️ مخصص', class: 'badge-info' }
    };

    let html = '';
    listToRender.forEach((r, idx) => {
        const isDomain = r.rule_type === 'domain';
        const typeBadge = isDomain
            ? '<span class="status-badge" style="background: rgba(6,182,212,0.15); color: #06b6d4;"><i class="fa-solid fa-globe"></i> رابط موقع</span>'
            : '<span class="status-badge" style="background: rgba(168,85,247,0.15); color: #a855f7;"><i class="fa-solid fa-font"></i> كلمة بحث</span>';

        const catInfo = categoryNames[r.category] || { text: r.category || 'عام', class: 'badge-info' };
        const statusBadge = r.is_active
            ? '<span class="status-badge status-badge-active">مفعل</span>'
            : '<span class="status-badge status-badge-paused">معطل</span>';

        const dateStr = r.created_at ? new Date(r.created_at).toLocaleDateString('ar-EG', { month: 'short', day: 'numeric' }) : '---';

        html += `
        <tr id="web-rule-row-${r.id}">
            <td class="text-muted">${idx + 1}</td>
            <td>${typeBadge}</td>
            <td>
                <span style="font-weight: 600; font-family: monospace; font-size: 0.95rem; direction: ltr; display: inline-block;">
                    ${escapeHtml(r.pattern)}
                </span>
            </td>
            <td><span class="status-badge" style="font-size: 0.78rem;">${catInfo.text}</span></td>
            <td class="text-muted" style="font-size: 0.82rem;">${dateStr}</td>
            <td>${statusBadge}</td>
            <td style="text-align: center;">
                <label class="switch-toggle" style="margin: 0;">
                    <input type="checkbox" ${r.is_active ? 'checked' : ''} onchange="toggleSingleWebFilterRule('${r.id}', this.checked)">
                    <span class="slider-round"></span>
                </label>
            </td>
            <td style="text-align: center;">
                <button class="btn-icon-danger" title="حذف القاعدة" onclick="deleteSingleWebFilterRule('${r.id}')" style="background: none; border: none; color: #ef4444; cursor: pointer; font-size: 1rem; padding: 4px 8px;">
                    <i class="fa-solid fa-trash-can"></i>
                </button>
            </td>
        </tr>
        `;
    });

    tbody.innerHTML = html;
}

async function toggleWebFilterEngine() {
    if (!STATE.activeDeviceId) return;
    const nextState = !webFilterState.is_web_filter_enabled;
    webFilterState.is_web_filter_enabled = nextState;
    renderWebFilterUI();

    try {
        await API.toggleWebFilterEngine(STATE.activeDeviceId, nextState);
        UI.showToast(nextState ? '🟢 تم تفعيل محرك حظر وتصفية الويب' : '⏸️ تم إيقاف محرك تصفية الويب مؤقتاً', 'success');
    } catch (e) {
        webFilterState.is_web_filter_enabled = !nextState;
        renderWebFilterUI();
        UI.showToast(`فشل تغيير حالة محرك الويب: ${e.message}`, 'error');
    }
}

async function toggleAllWebFilterRules(enabled) {
    if (!STATE.activeDeviceId) return;
    try {
        await API.toggleAllWebFilterRules(STATE.activeDeviceId, enabled);
        (webFilterState.rules || []).forEach(r => r.is_active = enabled);
        renderWebFilterUI();
        UI.showToast(enabled ? 'تم تفعيل جميع قواعد الويب بنجاح' : 'تم تعطيل جميع قواعد الويب', 'success');
    } catch (e) {
        UI.showToast(`فشل تحديث القواعد: ${e.message}`, 'error');
    }
}

async function toggleSingleWebFilterRule(ruleId, isActive) {
    if (!STATE.activeDeviceId) return;
    try {
        await API.toggleWebFilterRule(STATE.activeDeviceId, ruleId, isActive);
        const rule = (webFilterState.rules || []).find(r => r.id === ruleId);
        if (rule) rule.is_active = isActive;
        renderWebFilterUI();
        UI.showToast(isActive ? 'تم تفعيل القاعدة' : 'تم تعطيل القاعدة', 'success');
    } catch (e) {
        UI.showToast(`فشل تغيير حالة القاعدة: ${e.message}`, 'error');
        renderWebFilterUI();
    }
}

async function deleteSingleWebFilterRule(ruleId) {
    if (!STATE.activeDeviceId) return;
    if (!confirm('هل أنت متأكد من حذف هذه القاعدة من قائمة الحظر؟')) return;

    try {
        await API.deleteWebFilterRule(STATE.activeDeviceId, ruleId);
        webFilterState.rules = (webFilterState.rules || []).filter(r => r.id !== ruleId);
        renderWebFilterUI();
        UI.showToast('تم حذف القاعدة بنجاح', 'success');
    } catch (e) {
        UI.showToast(`فشل حذف القاعدة: ${e.message}`, 'error');
    }
}

async function seedWebFilterDefaults() {
    if (!STATE.activeDeviceId) {
        UI.showToast('يرجى تحديد جهاز الطفل أولاً', 'warning');
        return;
    }
    try {
        UI.showToast('جاري تحميل وتفعيل القوائم الافتراضية الذكية...', 'info');
        const res = await API.seedWebFilterDefaults(STATE.activeDeviceId);
        await loadWebFilter(true);
        UI.showToast(`⚡ تم تحميل وتفعيل ${res.total || '83'} قاعدة ذكية بنجاح!`, 'success');
    } catch (e) {
        UI.showToast(`فشل تحميل القوائم الافتراضية: ${e.message}`, 'error');
    }
}

function openAddWebFilterModal() {
    const modal = document.getElementById('addWebFilterModal');
    if (modal) modal.style.display = 'flex';
}

function closeAddWebFilterModal() {
    const modal = document.getElementById('addWebFilterModal');
    if (modal) modal.style.display = 'none';
}

async function submitAddWebFilterRule(e) {
    e.preventDefault();
    if (!STATE.activeDeviceId) return;

    const form = document.getElementById('addWebFilterForm');
    const ruleType = form.querySelector('input[name="rule_type"]:checked')?.value || 'keyword';
    const pattern = document.getElementById('rulePatternInput').value.trim();
    const category = document.getElementById('ruleCategorySelect').value || 'custom';

    if (!pattern) return;

    const btn = document.getElementById('btnSubmitAddWebFilter');
    if (btn) btn.disabled = true;

    try {
        await API.createWebFilterRule(STATE.activeDeviceId, {
            rule_type: ruleType,
            pattern: pattern,
            category: category
        });

        await loadWebFilter(true);
        closeAddWebFilterModal();
        document.getElementById('rulePatternInput').value = '';
        UI.showToast(`تمت إضافة ${ruleType === 'domain' ? 'الموقع' : 'الكلمة'} (${pattern}) إلى قائمة الحظر بنجاح`, 'success');
    } catch (err) {
        UI.showToast(`فشل إضافة القاعدة: ${err.message}`, 'error');
    } finally {
        if (btn) btn.disabled = false;
    }
}

function searchWebRules(q) {
    const query = q.toLowerCase();
    const filtered = (webFilterState.rules || []).filter(r =>
        (r.pattern || '').toLowerCase().includes(query) ||
        (r.category || '').toLowerCase().includes(query)
    );
    renderWebFilterUI(filtered);
}

function filterWebRules(category, pillEl) {
    document.querySelectorAll('#webFilterSection .filter-pill').forEach(p => p.classList.remove('active'));
    if (pillEl) pillEl.classList.add('active');
    currentWebFilterCategory = category;

    let filtered = webFilterState.rules || [];
    if (category === 'keyword') filtered = filtered.filter(r => r.rule_type === 'keyword');
    else if (category === 'domain') filtered = filtered.filter(r => r.rule_type === 'domain');
    else if (category !== 'all') filtered = filtered.filter(r => r.category === category);

    renderWebFilterUI(filtered);
}

function onWebFilterUpdatedWS(payload) {
    if (payload && typeof payload.is_web_filter_enabled === 'boolean') {
        webFilterState.is_web_filter_enabled = payload.is_web_filter_enabled;
    }
    loadWebFilter();
}

window.loadWebFilter = loadWebFilter;
window.toggleWebFilterEngine = toggleWebFilterEngine;
window.toggleAllWebFilterRules = toggleAllWebFilterRules;
window.toggleSingleWebFilterRule = toggleSingleWebFilterRule;
window.deleteSingleWebFilterRule = deleteSingleWebFilterRule;
window.seedWebFilterDefaults = seedWebFilterDefaults;
window.openAddWebFilterModal = openAddWebFilterModal;
window.closeAddWebFilterModal = closeAddWebFilterModal;
window.submitAddWebFilterRule = submitAddWebFilterRule;
window.searchWebRules = searchWebRules;
window.filterWebRules = filterWebRules;
window.onWebFilterUpdatedWS = onWebFilterUpdatedWS;

// ==========================================
// BROWSER HISTORY & SAFE SEARCH EXPLORER
// ==========================================

let browserHistoryState = {
    items: [],
    stats: {
        total_visits: 0,
        today_visits: 0,
        total_searches: 0,
        blocked_hits: 0,
        top_searches: [],
        top_domains: []
    },
    currentFilter: 'all',
    searchQuery: '',
    searchDebounceTimer: null
};

async function loadBrowserHistory(force = false) {
    if (!STATE.activeDeviceId) return;
    const spin = document.getElementById('refreshHistoryIcon');
    if (spin) spin.classList.add('fa-spin');

    try {
        const [historyRes, statsRes] = await Promise.allSettled([
            API.getBrowserHistory(STATE.activeDeviceId, { limit: 150 }),
            API.getBrowserHistoryStats(STATE.activeDeviceId)
        ]);

        if (historyRes.status === 'fulfilled' && historyRes.value) {
            browserHistoryState.items = historyRes.value.history || [];
            const countBadge = document.getElementById('historyCountBadge');
            if (countBadge) countBadge.textContent = browserHistoryState.items.length;
        }

        if (statsRes.status === 'fulfilled' && statsRes.value) {
            browserHistoryState.stats = statsRes.value;
        }

        renderBrowserHistoryUI();
    } catch (e) {
        console.error('Failed to load browser history:', e);
        const tbody = document.getElementById('browserHistoryTableBody');
        if (tbody) {
            tbody.innerHTML = `<tr><td colspan="9" class="text-center text-danger" style="padding: 25px;">فشل تحميل سجل التصفح: ${e.message}</td></tr>`;
        }
    } finally {
        if (spin) spin.classList.remove('fa-spin');
    }
}

function renderBrowserHistoryUI() {
    const stats = browserHistoryState.stats;
    const items = browserHistoryState.items || [];

    // 1. Stats Cards
    const statTotalSites = document.getElementById('statHistoryTotalSites');
    if (statTotalSites) {
        const totalVisits = (stats && stats.total_visits) ? stats.total_visits : items.length;
        statTotalSites.textContent = totalVisits.toLocaleString();
    }
    const statTodaySub = document.getElementById('statHistoryTodaySub');
    if (statTodaySub && stats && stats.today_visits !== undefined) {
        statTodaySub.textContent = `زيارات اليوم: ${stats.today_visits} موقع`;
    }

    const statSearches = document.getElementById('statHistoryTotalSearches');
    if (statSearches) {
        const totalSearches = (stats && stats.total_searches) ? stats.total_searches : items.filter(i => i.is_search_query || i.search_query).length;
        statSearches.textContent = totalSearches.toLocaleString();
    }

    const statTopDomain = document.getElementById('statHistoryTopDomain');
    const statTopDomainCount = document.getElementById('statHistoryTopDomainCount');
    if (statTopDomain && statTopDomainCount) {
        if (stats && stats.top_domains && stats.top_domains.length > 0) {
            statTopDomain.textContent = stats.top_domains[0].domain;
            statTopDomain.title = stats.top_domains[0].domain;
            statTopDomainCount.textContent = `${stats.top_domains[0].count} زيارة مسجلة`;
        } else if (items.length > 0) {
            // Calculate top domain locally
            const domCounts = {};
            items.forEach(i => { if (i.domain) domCounts[i.domain] = (domCounts[i.domain] || 0) + (i.visit_count || 1); });
            const sortedDom = Object.entries(domCounts).sort((a, b) => b[1] - a[1]);
            if (sortedDom.length > 0) {
                statTopDomain.textContent = sortedDom[0][0];
                statTopDomain.title = sortedDom[0][0];
                statTopDomainCount.textContent = `${sortedDom[0][1]} زيارة مسجلة`;
            }
        } else {
            statTopDomain.textContent = '--';
            statTopDomainCount.textContent = 'لا توجد زيارات مسجلة';
        }
    }

    const statBlockedInfo = document.getElementById('statHistoryBlockedInfo');
    if (statBlockedInfo) {
        const blockedCount = (stats && stats.blocked_hits) ? stats.blocked_hits : items.filter(i => i.is_blocked).length;
        statBlockedInfo.textContent = `تم منع ${blockedCount} محاولة محظورة`;
    }

    // 2. Search Keywords Cloud (Radar for Google & YouTube)
    const searchContainer = document.getElementById('topSearchesContainer');
    if (searchContainer) {
        let topSearches = (stats && stats.top_searches && stats.top_searches.length > 0) ? stats.top_searches : [];
        if (topSearches.length === 0) {
            // Extract from items locally if stats not populated yet
            const qMap = {};
            items.forEach(i => {
                const q = i.search_query || (i.is_search_query ? i.title : null);
                if (q && q.trim().length > 1) {
                    qMap[q.trim()] = (qMap[q.trim()] || 0) + (i.visit_count || 1);
                }
            });
            topSearches = Object.entries(qMap).map(([query, count]) => ({ query, count })).sort((a, b) => b.count - a.count).slice(0, 15);
        }

        if (topSearches.length > 0) {
            searchContainer.innerHTML = topSearches.map(s => {
                const isYouTube = s.query.toLowerCase().includes('youtube') || s.query.toLowerCase().includes('فيديو') || s.query.toLowerCase().includes('اغنية') || s.query.toLowerCase().includes('مقطع');
                const engineIcon = isYouTube ? '<i class="fa-brands fa-youtube" style="color: #ef4444;"></i>' : '<i class="fa-brands fa-google" style="color: #4285f4;"></i>';
                const chipBg = isYouTube ? 'rgba(239, 68, 68, 0.12)' : 'rgba(139, 92, 246, 0.15)';
                const chipBorder = isYouTube ? 'rgba(239, 68, 68, 0.35)' : 'rgba(139, 92, 246, 0.35)';
                const badgeColor = isYouTube ? '#ef4444' : '#8b5cf6';

                return `
                    <div class="search-keyword-chip" style="background: ${chipBg}; border-color: ${chipBorder};" onclick="applyHistorySearchFilter('${escapeHtml(s.query)}')" title="تصفية السجل بعبارة: ${escapeHtml(s.query)}">
                        ${engineIcon}
                        <span class="kw-text" style="font-weight: 600;">${escapeHtml(s.query)}</span>
                        <span class="kw-count" style="background: ${badgeColor};">${s.count}</span>
                    </div>
                `;
            }).join('');
        } else {
            searchContainer.innerHTML = '<span class="text-muted" style="font-size: 0.85rem;"><i class="fa-solid fa-info-circle"></i> لا توجد استعلامات بحث مسجلة حتى الآن من Google أو YouTube.</span>';
        }
    }

    // 3. Filter Pill Counts
    const searchesCount = items.filter(i => i.is_search_query || i.search_query).length;
    const blockedCount = items.filter(i => i.is_blocked).length;

    const countAllEl = document.getElementById('countAllHistory');
    if (countAllEl) countAllEl.textContent = items.length;
    const countSearchesEl = document.getElementById('countSearchesHistory');
    if (countSearchesEl) countSearchesEl.textContent = searchesCount;
    const countBlockedEl = document.getElementById('countBlockedHistory');
    if (countBlockedEl) countBlockedEl.textContent = blockedCount;

    // 4. Apply Filters
    let displayItems = [...items];
    const filter = browserHistoryState.currentFilter;
    if (filter === 'searches') {
        displayItems = displayItems.filter(i => i.is_search_query || i.search_query);
    } else if (filter === 'top-visited') {
        // Sort by visit count descending for most frequent
        displayItems.sort((a, b) => (b.visit_count || 1) - (a.visit_count || 1));
    } else if (filter === 'blocked') {
        displayItems = displayItems.filter(i => i.is_blocked);
    } else if (filter === 'chrome') {
        displayItems = displayItems.filter(i => (i.browser || '').toLowerCase().includes('chrome'));
    } else if (filter === 'edge') {
        displayItems = displayItems.filter(i => (i.browser || '').toLowerCase().includes('edge'));
    } else if (filter === 'firefox') {
        displayItems = displayItems.filter(i => (i.browser || '').toLowerCase().includes('firefox'));
    }

    // Apply Live Search Query
    if (browserHistoryState.searchQuery) {
        const q = browserHistoryState.searchQuery.toLowerCase();
        displayItems = displayItems.filter(i => 
            (i.title && i.title.toLowerCase().includes(q)) ||
            (i.url && i.url.toLowerCase().includes(q)) ||
            (i.search_query && i.search_query.toLowerCase().includes(q)) ||
            (i.domain && i.domain.toLowerCase().includes(q))
        );
    }

    // 5. Render Table Rows
    const tbody = document.getElementById('browserHistoryTableBody');
    if (!tbody) return;

    if (displayItems.length === 0) {
        tbody.innerHTML = `
            <tr>
                <td colspan="9" class="text-center text-muted" style="padding: 40px;">
                    <i class="fa-solid fa-clock-rotate-left" style="font-size: 2.4rem; opacity: 0.25; margin-bottom: 12px; display: block;"></i>
                    <div style="font-size: 1rem; color: #cbd5e1;">لا توجد سجلات تصفح أو بحث تطابق هذا الفلتر</div>
                    <span class="sub-text" style="font-size: 0.8rem; color: #64748b;">تأكد من اختيار جهاز نشط ومزامنة متصفحات الويب</span>
                </td>
            </tr>
        `;
        return;
    }

    tbody.innerHTML = displayItems.map((item, idx) => {
        // Browser Icon
        let browserIcon = '<i class="fa-brands fa-chrome" style="color: #ea4335;" title="Google Chrome"></i>';
        const b = (item.browser || '').toLowerCase();
        if (b.includes('edge')) {
            browserIcon = '<i class="fa-brands fa-edge" style="color: #0078d7;" title="Microsoft Edge"></i>';
        } else if (b.includes('firefox')) {
            browserIcon = '<i class="fa-brands fa-firefox-browser" style="color: #ff7139;" title="Mozilla Firefox"></i>';
        } else if (b.includes('android')) {
            browserIcon = '<i class="fa-brands fa-android" style="color: #10b981;" title="متصفح أندرويد"></i>';
        }

        // Search highlight vs regular URL
        let urlDisplay = '';
        let activityBadge = '';
        if (item.is_search_query || item.search_query) {
            const isYt = (item.domain || '').includes('youtube');
            const platform = isYt ? 'YouTube' : 'Google';
            const icon = isYt ? '<i class="fa-brands fa-youtube" style="color: #ef4444;"></i>' : '<i class="fa-brands fa-google" style="color: #4285f4;"></i>';
            activityBadge = `<span class="status-badge" style="background: rgba(139, 92, 246, 0.2); color: #c084fc; border: 1px solid rgba(139, 92, 246, 0.4);">${icon} بحث ${platform}</span>`;
            urlDisplay = `
                <div style="display: flex; align-items: center; gap: 6px; margin-bottom: 2px;">
                    <span class="search-term-highlight">🔍 ${escapeHtml(item.search_query || item.title)}</span>
                </div>
                <a href="${escapeHtml(item.url)}" target="_blank" rel="noopener" class="sub-text text-truncate" style="max-width: 320px; display: inline-block; color: rgba(255,255,255,0.4); font-size: 0.75rem;" title="${escapeHtml(item.url)}">${escapeHtml(item.url)}</a>
            `;
        } else {
            activityBadge = `<span class="status-badge" style="background: rgba(6, 182, 212, 0.15); color: #22d3ee; border: 1px solid rgba(6, 182, 212, 0.3);"><i class="fa-solid fa-globe"></i> زيارة موقع</span>`;
            urlDisplay = `<a href="${escapeHtml(item.url)}" target="_blank" rel="noopener" class="text-truncate" style="max-width: 380px; display: inline-block; color: var(--accent-cyan); font-weight: 500;" title="${escapeHtml(item.url)}">${escapeHtml(item.url)}</a>`;
        }

        // Status Badge
        const statusBadge = item.is_blocked
            ? '<span class="status-badge status-badge-paused"><i class="fa-solid fa-ban"></i> محظور 🚫</span>'
            : '<span class="status-badge status-badge-active"><i class="fa-solid fa-circle-check"></i> تم التصفح</span>';

        // Instant Block Button: calls API.createWebFilterRule directly
        const blockBtn = item.is_blocked
            ? `<button class="btn btn-outline-sm text-muted" disabled style="opacity: 0.55; cursor: not-allowed;"><i class="fa-solid fa-lock"></i> محظور</button>`
            : `<button class="btn btn-outline-sm text-danger" onclick="quickBlockBrowserDomain('${escapeHtml(item.domain)}', '${escapeHtml(item.title || item.domain)}')" title="حظر هذا الموقع فوراً وإضافته لمحرك الفلترة"><i class="fa-solid fa-ban"></i> حظر هذا الموقع</button>`;

        // Date and Time Formatting
        let formattedDate = '-';
        if (item.visited_at) {
            try {
                const d = new Date(item.visited_at);
                formattedDate = d.toLocaleString('ar-EG', {
                    year: 'numeric',
                    month: 'short',
                    day: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit',
                    hour12: true
                });
            } catch (_) {
                formattedDate = item.visited_at;
            }
        }

        return `
            <tr class="${item.is_blocked ? 'row-blocked' : ''}">
                <td class="text-muted" style="font-size: 0.8rem;">${idx + 1}</td>
                <td>
                    <div style="display: flex; align-items: center; gap: 8px; font-size: 1.15rem;">
                        ${browserIcon}
                        <span style="font-size: 0.82rem; text-transform: capitalize; color: #cbd5e1;">${escapeHtml(item.browser)}</span>
                    </div>
                </td>
                <td>
                    <div style="font-weight: 600; color: #fff; max-width: 250px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;" title="${escapeHtml(item.title || item.domain)}">
                        ${escapeHtml(item.title || item.domain)}
                    </div>
                    <span class="sub-text" style="font-size: 0.75rem; color: #94a3b8; display: flex; align-items: center; gap: 4px; margin-top: 2px;">
                        <i class="fa-solid fa-link" style="font-size: 0.68rem; color: var(--accent-cyan);"></i> ${escapeHtml(item.domain)}
                    </span>
                </td>
                <td>${urlDisplay}</td>
                <td>${activityBadge}</td>
                <td style="text-align: center;">
                    <span class="badge" style="background: rgba(255,255,255,0.08); font-size: 0.8rem; padding: 3px 9px; border-radius: 6px; font-weight: 700; color: #e2e8f0;">
                        ${item.visit_count || 1}
                    </span>
                </td>
                <td style="font-size: 0.8rem; color: #cbd5e1; direction: ltr; text-align: right;" title="${item.visited_at}">
                    ${formattedDate}
                </td>
                <td style="text-align: center;">${statusBadge}</td>
                <td style="text-align: center;">${blockBtn}</td>
            </tr>
        `;
    }).join('');
}

function filterBrowserHistory(filterType, btnEl) {
    browserHistoryState.currentFilter = filterType;
    if (btnEl) {
        document.querySelectorAll('#browserHistorySection .filter-pill').forEach(b => b.classList.remove('active'));
        btnEl.classList.add('active');
    }
    renderBrowserHistoryUI();
}

function debounceSearchHistory(query) {
    clearTimeout(browserHistoryState.searchDebounceTimer);
    browserHistoryState.searchDebounceTimer = setTimeout(() => {
        browserHistoryState.searchQuery = query.trim();
        renderBrowserHistoryUI();
    }, 250);
}

function applyHistorySearchFilter(query) {
    const input = document.getElementById('browserHistorySearchInput');
    if (input) input.value = query;
    browserHistoryState.searchQuery = query;
    renderBrowserHistoryUI();
}

async function confirmClearBrowserHistory() {
    if (!STATE.activeDeviceId) return;
    if (!confirm('هل أنت متأكد من مسح سجل التصفح والبحث لهذا الجهاز بشكل نهائي؟')) return;

    try {
        await API.clearBrowserHistory(STATE.activeDeviceId);
        UI.toast('تم مسح سجل التصفح بنجاح', 'success');
        await loadBrowserHistory(true);
    } catch (e) {
        console.error('Clear history error:', e);
        UI.toast('فشل مسح السجل: ' + e.message, 'error');
    }
}

// Instant Block Button: Directly invokes API.createWebFilterRule to enforce immediate block
async function quickBlockBrowserDomain(domain, title) {
    if (!STATE.activeDeviceId || !domain) return;
    if (!confirm(`هل تريد حظر الموقع "${domain}" فوراً وتطبيق الحظر بلحظتها على أجهزة الطفل؟`)) return;

    try {
        // 1. Directly invoke API.createWebFilterRule as specified
        await API.createWebFilterRule(STATE.activeDeviceId, {
            rule_type: 'domain',
            pattern: domain,
            description: title ? `حظر فوري من سجل التصفح: ${title}` : `حظر فوري للنطاق: ${domain}`,
            action: 'block',
            category: 'custom'
        });

        // 2. Also register in browser history backend quick-block for immediate sync
        try {
            await API.quickBlockBrowserDomain(STATE.activeDeviceId, { domain, title });
        } catch (_) {}

        // 3. Dispatch WebSocket live update to the child agent device
        if (window.WS && typeof window.WS.send === 'function') {
            window.WS.send('WEB_FILTER_UPDATED', {
                is_web_filter_enabled: true,
                target_domain: domain
            }, STATE.activeDeviceId);
        }

        UI.toast(`تم حظر الموقع "${domain}" وتطبيق الحظر بلحظتها بنجاح! 🚫`, 'success');

        // Update local item states
        browserHistoryState.items.forEach(i => {
            if (i.domain === domain) i.is_blocked = true;
        });
        renderBrowserHistoryUI();

        // Refresh web filter rules UI if present
        if (window.loadWebFilter) window.loadWebFilter(true);
    } catch (e) {
        console.error('Quick block error:', e);
        UI.toast('فشل تطبيق الحظر: ' + e.message, 'error');
    }
}

window.loadBrowserHistory = loadBrowserHistory;
window.renderBrowserHistoryUI = renderBrowserHistoryUI;
window.filterBrowserHistory = filterBrowserHistory;
window.debounceSearchHistory = debounceSearchHistory;
window.applyHistorySearchFilter = applyHistorySearchFilter;
window.confirmClearBrowserHistory = confirmClearBrowserHistory;
window.quickBlockBrowserDomain = quickBlockBrowserDomain;

// === Standalone Full-Screen Auth Functions ===
let currentAuthTab = 'login';

function switchAuthTab(tab) {
    currentAuthTab = tab;
    const tabLogin = document.getElementById('tabBtnLogin');
    const tabRegister = document.getElementById('tabBtnRegister');
    const formLogin = document.getElementById('loginForm');
    const formRegister = document.getElementById('registerForm');

    hideAuthAlert();

    if (tab === 'register') {
        if (tabLogin) tabLogin.classList.remove('active');
        if (tabRegister) tabRegister.classList.add('active');
        if (formLogin) formLogin.style.display = 'none';
        if (formRegister) {
            formRegister.style.display = 'block';
            const firstInput = document.getElementById('regFullName');
            if (firstInput) setTimeout(() => firstInput.focus(), 50);
        }
    } else {
        if (tabRegister) tabRegister.classList.remove('active');
        if (tabLogin) tabLogin.classList.add('active');
        if (formRegister) formRegister.style.display = 'none';
        if (formLogin) {
            formLogin.style.display = 'block';
            const firstInput = document.getElementById('loginEmail');
            if (firstInput) setTimeout(() => firstInput.focus(), 50);
        }
    }
}

function showAuthAlert(message, type = 'error') {
    const banner = document.getElementById('authAlertBanner');
    const icon = document.getElementById('authAlertIcon');
    const text = document.getElementById('authAlertText');
    if (!banner || !text) return;

    banner.className = `auth-alert-banner alert-${type}`;
    if (icon) {
        icon.className = type === 'success' 
            ? 'fa-solid fa-circle-check' 
            : 'fa-solid fa-circle-exclamation';
    }
    text.textContent = message;
    banner.style.display = 'flex';
}

function hideAuthAlert() {
    const banner = document.getElementById('authAlertBanner');
    if (banner) {
        banner.style.display = 'none';
        banner.className = 'auth-alert-banner';
    }
}

function togglePasswordVisibility(inputId, btn) {
    const input = document.getElementById(inputId);
    if (!input) return;
    const isPass = input.type === 'password';
    input.type = isPass ? 'text' : 'password';
    if (btn) {
        const icon = btn.querySelector('i');
        if (icon) {
            icon.className = isPass ? 'fa-solid fa-eye-slash' : 'fa-solid fa-eye';
        }
    }
}

function checkPasswordStrength(password) {
    const bar = document.getElementById('regStrengthBar');
    if (!bar) return;

    bar.className = 'meter-bar';
    if (!password) {
        bar.style.width = '0%';
        return;
    }

    let score = 0;
    if (password.length >= 6) score++;
    if (password.length >= 8) score++;
    if (/[A-Z]/.test(password) || /[a-z]/.test(password)) score++;
    if (/[0-9]/.test(password)) score++;
    if (/[^A-Za-z0-9]/.test(password)) score++;

    if (score <= 2) {
        bar.classList.add('meter-weak');
    } else if (score <= 4) {
        bar.classList.add('meter-medium');
    } else {
        bar.classList.add('meter-strong');
    }
}

function fillAndLoginDemo() {
    const emailInput = document.getElementById('loginEmail');
    const passInput = document.getElementById('loginPassword');
    if (emailInput) emailInput.value = 'admin@parentalcontrol.local';
    if (passInput) passInput.value = 'Admin@123456';
    
    // Auto trigger login
    const form = document.getElementById('loginForm');
    if (form) {
        submitLogin(new Event('submit', { cancelable: true }));
    }
}

function forgotPasswordHint() {
    UI.showToast('يمكنك استخدام الحساب التجريبي المعتمد (admin@parentalcontrol.local) أو التواصل مع مسؤول النظام لإعادة تعيين كلمة المرور.', 'info');
}

async function submitLogin(e) {
    if (e && typeof e.preventDefault === 'function') e.preventDefault();
    hideAuthAlert();

    const emailInput = document.getElementById('loginEmail');
    const passwordInput = document.getElementById('loginPassword');
    const btn = document.getElementById('btnLoginSubmit');

    const email = emailInput ? emailInput.value.trim() : '';
    const password = passwordInput ? passwordInput.value : '';

    if (!email || !password) {
        showAuthAlert('يرجى إدخال البريد الإلكتروني وكلمة المرور');
        return;
    }

    // Set loading state on button
    let loader = btn ? btn.querySelector('.btn-loader') : null;
    let arrow = btn ? btn.querySelector('.btn-arrow') : null;
    if (btn) btn.disabled = true;
    if (loader) loader.style.display = 'inline-block';
    if (arrow) arrow.style.display = 'none';

    try {
        const res = await API.login(email, password);
        const token = res.tokens?.access_token || res.token || res.accessToken;
        if (!token) {
            throw new Error('لم يتم استلام مفتاح الأمان (Token) من الخادم');
        }

        localStorage.setItem('parent_jwt_token', token);
        STATE.token = token;
        if (res.user) {
            STATE.user = res.user;
            localStorage.setItem('parent_user', JSON.stringify(res.user));
        }

        showAuthAlert('تم تسجيل الدخول بنجاح! جاري تحضير اللوحة...', 'success');
        UI.showToast('أهلاً بك! تم تسجيل الدخول بنجاح', 'success');

        // Smooth reveal of dashboard
        setTimeout(async () => {
            const authScreen = document.getElementById('authScreen');
            const dashboardApp = document.getElementById('dashboardAppLayout');
            if (authScreen) authScreen.style.display = 'none';
            if (dashboardApp) dashboardApp.style.display = 'grid';

            await App.init();
        }, 400);

    } catch (err) {
        console.error('[Login Error]', err);
        const errorMsg = err.message || 'فشل تسجيل الدخول. تأكد من صحة البيانات والاتصال بالخادم.';
        showAuthAlert(errorMsg, 'error');
        UI.showToast(errorMsg, 'error');
    } finally {
        if (btn) btn.disabled = false;
        if (loader) loader.style.display = 'none';
        if (arrow) arrow.style.display = 'inline-block';
    }
}

async function submitRegister(e) {
    if (e && typeof e.preventDefault === 'function') e.preventDefault();
    hideAuthAlert();

    const fullNameInput = document.getElementById('regFullName');
    const emailInput = document.getElementById('regEmail');
    const familyNameInput = document.getElementById('regFamilyName');
    const phoneInput = document.getElementById('regPhone');
    const passInput = document.getElementById('regPassword');
    const passConfirmInput = document.getElementById('regPasswordConfirm');
    const agreeTerms = document.getElementById('agreeTerms');
    const btn = document.getElementById('btnRegisterSubmit');

    const fullName = fullNameInput ? fullNameInput.value.trim() : '';
    const email = emailInput ? emailInput.value.trim() : '';
    const familyName = familyNameInput ? familyNameInput.value.trim() : '';
    const phone = phoneInput ? phoneInput.value.trim() : '';
    const password = passInput ? passInput.value : '';
    const passwordConfirm = passConfirmInput ? passConfirmInput.value : '';

    if (!fullName) {
        showAuthAlert('يرجى إدخال الاسم الكامل لولي الأمر');
        return;
    }
    if (!email) {
        showAuthAlert('يرجى إدخال البريد الإلكتروني');
        return;
    }
    if (!password || password.length < 6) {
        showAuthAlert('يجب أن تتكون كلمة المرور من 6 أحرف أو أرقام على الأقل');
        return;
    }
    if (password !== passwordConfirm) {
        showAuthAlert('كلمتا المرور غير متطابقتين، يرجى التأكد وإعادة المحاولة');
        return;
    }
    if (agreeTerms && !agreeTerms.checked) {
        showAuthAlert('يجب الموافقة على شروط الاستخدام وسياسة حماية خصوصية الأطفال للمتابعة');
        return;
    }

    let loader = btn ? btn.querySelector('.btn-loader') : null;
    let arrow = btn ? btn.querySelector('.btn-arrow') : null;
    if (btn) btn.disabled = true;
    if (loader) loader.style.display = 'inline-block';
    if (arrow) arrow.style.display = 'none';

    try {
        const payload = {
            full_name: fullName,
            email: email,
            password: password,
            family_name: familyName,
            phone_number: phone
        };

        const res = await API.register(payload);
        showAuthAlert('تم إنشاء حسابك بنجاح! جاري تسجيل الدخول التلقائي...', 'success');
        UI.showToast('تم إنشاء الحساب بنجاح!', 'success');

        let token = res.tokens?.access_token || res.token || res.accessToken;
        if (!token) {
            // If register didn't return tokens directly, log in automatically
            const loginRes = await API.login(email, password);
            token = loginRes.tokens?.access_token || loginRes.token || loginRes.accessToken;
            if (loginRes.user) res.user = loginRes.user;
        }

        if (token) {
            localStorage.setItem('parent_jwt_token', token);
            STATE.token = token;
            if (res.user) {
                STATE.user = res.user;
                localStorage.setItem('parent_user', JSON.stringify(res.user));
            }

            setTimeout(async () => {
                const authScreen = document.getElementById('authScreen');
                const dashboardApp = document.getElementById('dashboardAppLayout');
                if (authScreen) authScreen.style.display = 'none';
                if (dashboardApp) dashboardApp.style.display = 'grid';

                await App.init();
            }, 500);
        } else {
            // Fallback: switch to login tab
            switchAuthTab('login');
            const loginEmail = document.getElementById('loginEmail');
            if (loginEmail) loginEmail.value = email;
            showAuthAlert('تم إنشاء الحساب بنجاح، يمكنك الآن تسجيل الدخول', 'success');
        }

    } catch (err) {
        console.error('[Register Error]', err);
        const errorMsg = err.message || 'فشل إنشاء الحساب، قد يكون البريد الإلكتروني مسجلاً مسبقاً.';
        showAuthAlert(errorMsg, 'error');
        UI.showToast(errorMsg, 'error');
    } finally {
        if (btn) btn.disabled = false;
        if (loader) loader.style.display = 'none';
        if (arrow) arrow.style.display = 'inline-block';
    }
}

function logout() {
    localStorage.removeItem('parent_jwt_token');
    localStorage.removeItem('parent_user');
    STATE.token = '';
    STATE.subscription = null;
    STATE.children = [];
    STATE.devices = [];
    STATE.activeDeviceId = '';
    STATE.activeChildId = '';

    if (typeof WS !== 'undefined' && WS.disconnect) {
        WS.disconnect();
    }

    const authScreen = document.getElementById('authScreen');
    const dashboardApp = document.getElementById('dashboardAppLayout');

    if (dashboardApp) dashboardApp.style.display = 'none';
    if (authScreen) {
        authScreen.style.display = 'flex';
        switchAuthTab('login');
    }

    UI.showToast('تم تسجيل الخروج بنجاح', 'info');
}

// Backwards compatibility aliases
window.toggleAuthMode = () => switchAuthTab(currentAuthTab === 'login' ? 'register' : 'login');
window.handleAuthSubmit = (e) => (currentAuthTab === 'register' ? submitRegister(e) : submitLogin(e));
window.switchAuthTab = switchAuthTab;
window.submitLogin = submitLogin;
window.submitRegister = submitRegister;
window.fillAndLoginDemo = fillAndLoginDemo;
window.checkPasswordStrength = checkPasswordStrength;
window.togglePasswordVisibility = togglePasswordVisibility;
window.forgotPasswordHint = forgotPasswordHint;
window.logout = logout;

// === Add Child & Pairing Workflow ===
let _activePairInterval = null;
function openAddChildModal() {
    if (STATE.subscription) {
        if (STATE.subscription.is_expired || STATE.subscription.status !== 'active') {
            UI.showToast('لا يمكنك إضافة أجهزة جديدة نظراً لانتهاء صلاحية اشتراكك', 'error');
            UI.showSubscriptionExpiredModal(STATE.subscription);
            return;
        }
        if (STATE.subscription.used_devices >= STATE.subscription.max_devices) {
            UI.showToast(`لقد استهلكت الحد الأقصى للأجهزة في باقتك (${STATE.subscription.max_devices} أجهزة). يرجى ترقية الباقة.`, 'warning');
            UI.openModal('subscriptionModal');
            return;
        }
    }
    document.getElementById('addChildStep1').style.display = 'block';
    document.getElementById('addChildStep2').style.display = 'none';
    document.getElementById('newChildName').value = '';
    UI.openModal('addChildModal');
}

async function submitCreateChild() {
    const name = document.getElementById('newChildName').value.trim();
    if (!name) { UI.showToast('يرجى إدخال اسم الطفل', 'warning'); return; }

    const btn = document.getElementById('btnCreateChild');
    btn.disabled = true;

    try {
        const childRes = await API.createChild(name);
        const child = childRes.data || childRes.child || childRes;
        const childId = child.id;

        // Generate Pairing Code
        const pairRes = await API.generatePairCode(childId);
        const pairData = pairRes.data || pairRes;
        const code = pairData.code || '000000';
        window._currentGeneratedPairCode = code;

        // Display digits
        const digits = code.toString().split('');
        const digitsContainer = document.getElementById('pairCodeDigits');
        digitsContainer.innerHTML = digits.map(d => `<span class="code-digit">${d}</span>`).join('');

        // Render QR Code
        const qrBox = document.getElementById('pairQrCodeContainer');
        qrBox.innerHTML = '';
        const qrPayload = JSON.stringify({
            code: code,
            family_id: pairData.family_id,
            child_id: childId,
            server_url: window.APP_CONFIG?.wsBase?.replace('/ws', '') || window.location.origin
        });
        new QRCode(qrBox, { text: qrPayload, width: 170, height: 170, colorDark: "#000000", colorLight: "#ffffff" });

        // Countdown Timer (15 mins)
        let remainingSeconds = 15 * 60;
        clearInterval(_activePairInterval);
        _activePairInterval = setInterval(() => {
            remainingSeconds--;
            if (remainingSeconds <= 0) {
                clearInterval(_activePairInterval);
                document.getElementById('pairCodeTimer').textContent = 'انتهت الصلاحية';
                return;
            }
            const m = String(Math.floor(remainingSeconds / 60)).padStart(2, '0');
            const s = String(remainingSeconds % 60).padStart(2, '0');
            document.getElementById('pairCodeTimer').textContent = `${m}:${s}`;
        }, 1000);

        // Switch to Step 2
        document.getElementById('addChildStep1').style.display = 'none';
        document.getElementById('addChildStep2').style.display = 'block';
    } catch (e) {
        UI.showToast('فشل إنشاء الطفل: ' + e.message, 'error');
    } finally {
        btn.disabled = false;
    }
}

function copyPairCode() {
    const digits = Array.from(document.querySelectorAll('#pairCodeDigits .code-digit')).map(d => d.textContent).join('');
    navigator.clipboard.writeText(digits).then(() => UI.showToast('تم نسخ كود الاقتران', 'success'));
}

function finishPairingWorkflow() {
    clearInterval(_activePairInterval);
    UI.closeModal('addChildModal');
    App.loadChildren();
}

// === Geofence Form Helpers ===
window._isAddingGeofence = false;
window._selectedGeofenceLatLng = null;

function toggleAddGeofenceForm() {
    const f = document.getElementById('addGeofenceForm');
    window._isAddingGeofence = f.style.display === 'none';
    f.style.display = window._isAddingGeofence ? 'block' : 'none';
    if (window._isAddingGeofence) {
        UI.showToast('انقر على الخريطة لتحديد مركز المنطقة الآمنة', 'info');
    }
}

async function saveNewGeofence() {
    const name = document.getElementById('fenceName').value.trim();
    const radius = parseInt(document.getElementById('fenceRadius').value) || 300;
    const triggerType = document.getElementById('fenceTriggerType').value;

    if (!name) { UI.showToast('يرجى كتابة اسم المنطقة', 'warning'); return; }

    if (!STATE.activeChildId && STATE.children && STATE.children.length > 0) {
        STATE.activeChildId = STATE.children[0].id;
    }
    if (!STATE.activeChildId && STATE.activeDeviceId && STATE.devices) {
        const dev = STATE.devices.find(d => d.id === STATE.activeDeviceId);
        if (dev && dev.child_id) STATE.activeChildId = dev.child_id;
    }
    if (!STATE.activeChildId) {
        UI.showToast('يرجى تحديد طفل أولاً', 'warning');
        return;
    }

    const latlng = window._selectedGeofenceLatLng || MapController.marker?.getLatLng() || { lat: 24.7136, lng: 46.6753 };

    try {
        await API.createGeofence({
            child_id: STATE.activeChildId,
            name: name,
            latitude: latlng.lat,
            longitude: latlng.lng,
            radius: radius,
            radius_meters: radius,
            trigger_type: triggerType,
            alert_on_entry: triggerType === 'both' || triggerType === 'enter',
            alert_on_exit: triggerType === 'both' || triggerType === 'exit'
        });
        UI.showToast('تم حفظ وتفعيل المنطقة الآمنة بنجاح', 'success');
        document.getElementById('fenceName').value = '';
        window._selectedGeofenceLatLng = null;
        toggleAddGeofenceForm();
        App.loadGeofences();
    } catch (e) {
        UI.showToast('فشل حفظ المنطقة: ' + e.message, 'error');
    }
}

// === Screen Time Helpers ===
function updateDailyLimitLabel(val) {
    const h = Math.floor(val / 60);
    const m = val % 60;
    let label = `${val} دقيقة`;
    if (h > 0) label += ` (${h} ساعة${m > 0 ? ` و ${m} دقيقة` : ''})`;
    document.getElementById('dailyLimitMinutesLabel').textContent = label;
}

async function saveScreenTimeSettings() {
    const limit = parseInt(document.getElementById('dailyLimitSlider').value) || 120;
    const bedStart = document.getElementById('bedtimeStartInput').value;
    const bedEnd = document.getElementById('bedtimeEndInput').value;
    const enabled = document.getElementById('bedtimeEnabledCheck').checked;

    try {
        await API.saveScreenTimeRule(STATE.activeDeviceId, {
            daily_limit_minutes: limit,
            bedtime_start: bedStart,
            bedtime_end: bedEnd,
            is_enabled: enabled
        });
        UI.showToast('تم حفظ وتطبيق قواعد وقت الشاشة على جهاز الطفل', 'success');
    } catch (e) {
        UI.showToast('فشل حفظ القواعد: ' + e.message, 'error');
    }
}

// === E2EE Passphrase ===
function saveFamilyKey() {
    const val = document.getElementById('familyKeyInput').value.trim();
    if (!val) { UI.showToast('يرجى إدخال مفتاح التشفير', 'warning'); return; }
    STATE.familyKey = val;
    localStorage.setItem('family_e2ee_key', val);
    UI.closeModal('e2eeModal');
    UI.showToast('تم حفظ مفتاح التشفير التام وتفعيله', 'success');
    App.loadCalls();
    App.loadSMS();
}

function dismissRiskBanner() {
    document.getElementById('riskBanner').style.display = 'none';
}

// === Search & Filters ===
function searchApps(q) {
    const query = q.toLowerCase();
    const filtered = STATE.apps.filter(a =>
        (a.app_name || '').toLowerCase().includes(query) ||
        (a.package_name || '').toLowerCase().includes(query)
    );
    App.renderAppsTable(filtered);
}

function filterApps(category, pillEl) {
    document.querySelectorAll('.filter-pill').forEach(p => p.classList.remove('active'));
    pillEl.classList.add('active');

    let filtered = STATE.apps;
    if (category === 'user') filtered = STATE.apps.filter(a => !a.is_system);
    else if (category === 'system') filtered = STATE.apps.filter(a => a.is_system);
    else if (category === 'blocked') filtered = STATE.apps.filter(a => a.is_blocked);

    App.renderAppsTable(filtered);
}

function filterContacts(q) {
    const query = q.toLowerCase();
    const filtered = STATE.contacts.filter(c =>
        (c.name || '').toLowerCase().includes(query) ||
        (c.phone_number || '').includes(query)
    );
    App.renderContactsTable(filtered);
}

// === Device & Child Permanent Deletion & Unpair ===
function openDeleteDeviceModal(deviceId, childName, modelName, childId) {
    const targetDevId = deviceId || STATE.activeDeviceId;
    if (!targetDevId) {
        UI.showToast('يرجى تحديد جهاز لحذفه', 'warning');
        return;
    }

    const dev = STATE.devices.find(d => d.id === targetDevId);
    const child = dev ? STATE.children.find(c => c.id === dev.child_id) : (childId ? STATE.children.find(c => c.id === childId) : null);

    const cName = childName || (child ? child.name : 'جهاز الطفل');
    const mName = modelName || (dev ? dev.model : 'جهاز ذكي');

    const titleEl = document.getElementById('deleteModalTitle');
    const subtitleEl = document.getElementById('deleteModalSubtitle');
    const nameEl = document.getElementById('deleteTargetChildName');
    const infoEl = document.getElementById('deleteTargetDeviceInfo');
    const idEl = document.getElementById('deleteTargetDeviceId');
    const childIdEl = document.getElementById('deleteTargetChildId');
    const typeEl = document.getElementById('deleteTargetType');
    const iconEl = document.getElementById('deleteTargetIcon');

    if (titleEl) titleEl.textContent = 'حذف الجهاز وفك كافة القيود نهائياً';
    if (subtitleEl) subtitleEl.textContent = 'إلغاء اقتران دائم ومسح شامل لبيانات الجهاز والرقابة';
    if (nameEl) nameEl.textContent = cName;
    if (infoEl) infoEl.textContent = `${mName} (المعرف: ${targetDevId.substring(0, 8)}...)`;
    if (idEl) idEl.value = targetDevId;
    if (childIdEl) childIdEl.value = child ? child.id : (childId || '');
    if (typeEl) typeEl.value = 'device';

    if (iconEl && dev) {
        const isWindows = dev.os_type === 'windows' ||
                          (dev.model && dev.model.toLowerCase().includes('windows')) ||
                          (dev.os_version && dev.os_version.toLowerCase().includes('windows'));
        iconEl.className = isWindows ? 'fa-solid fa-laptop' : 'fa-solid fa-mobile-screen-button';
    }

    const modal = document.getElementById('deleteDeviceModal');
    if (modal) modal.style.display = 'flex';
}

function openDeleteChildModal(childId, childName) {
    if (!childId) {
        UI.showToast('يرجى تحديد طفل لحذفه', 'warning');
        return;
    }

    const child = STATE.children.find(c => c.id === childId);
    const cName = childName || (child ? child.name : 'ملف الطفل');

    const titleEl = document.getElementById('deleteModalTitle');
    const subtitleEl = document.getElementById('deleteModalSubtitle');
    const nameEl = document.getElementById('deleteTargetChildName');
    const infoEl = document.getElementById('deleteTargetDeviceInfo');
    const idEl = document.getElementById('deleteTargetDeviceId');
    const childIdEl = document.getElementById('deleteTargetChildId');
    const typeEl = document.getElementById('deleteTargetType');
    const iconEl = document.getElementById('deleteTargetIcon');

    if (titleEl) titleEl.textContent = 'حذف ملف الطفل نهائياً';
    if (subtitleEl) subtitleEl.textContent = 'حذف ملف الطفل ورموز الاقتران المرتبطة به بالكامل';
    if (nameEl) nameEl.textContent = cName;
    if (infoEl) infoEl.textContent = 'ملف طفل (لم يتم ربط جهاز بعد أو بانتظار الاقتران)';
    if (idEl) idEl.value = '';
    if (childIdEl) childIdEl.value = childId;
    if (typeEl) typeEl.value = 'child';

    if (iconEl) {
        iconEl.className = 'fa-solid fa-child';
    }

    const modal = document.getElementById('deleteDeviceModal');
    if (modal) modal.style.display = 'flex';
}

async function executeDeviceCompleteDeletion() {
    const typeEl = document.getElementById('deleteTargetType');
    const idEl = document.getElementById('deleteTargetDeviceId');
    const childIdEl = document.getElementById('deleteTargetChildId');

    const isChild = typeEl && typeEl.value === 'child';
    const deviceId = idEl ? idEl.value : '';
    const childId = childIdEl ? childIdEl.value : '';

    const btn = document.getElementById('btnConfirmDeleteDevice');
    const originalBtnHtml = btn ? btn.innerHTML : '';
    if (btn) {
        btn.disabled = true;
        btn.innerHTML = '<i class="fa-solid fa-circle-notch fa-spin"></i> جاري فك القيود والحذف...';
    }

    try {
        if (isChild || (!deviceId && childId)) {
            // Delete child profile directly via API
            await API.deleteChild(childId);
            UI.showToast('تم حذف ملف الطفل ورموز الاقتران بنجاح! 🚀', 'success');

            // Remove from local state
            STATE.children = STATE.children.filter(c => c.id !== childId);
            STATE.devices = STATE.devices.filter(d => d.child_id !== childId);

            if (STATE.activeChildId === childId) {
                if (STATE.children.length > 0) {
                    const nextChild = STATE.children[0];
                    const nextDev = STATE.devices.find(d => d.child_id === nextChild.id);
                    App.selectChild(nextChild.id, nextDev ? nextDev.id : '');
                } else {
                    STATE.activeDeviceId = null;
                    STATE.activeChildId = null;
                    localStorage.removeItem('active_device_id');
                    localStorage.removeItem('active_child_id');
                    App.updateActiveDeviceUI();
                }
            }
        } else {
            if (!deviceId) {
                UI.showToast('تعذر العثور على معرف الجهاز المطلوب حذفه', 'error');
                return;
            }

            // Always delete child profile if associated, to ensure full cascade wipe
            if (childId) {
                try {
                    await API.deleteChild(childId);
                } catch(e) {
                    await API.deleteDevice(deviceId);
                }
            } else {
                await API.deleteDevice(deviceId);
            }

            UI.showToast('تم حذف الجهاز وفك كافة القيود نهائياً بنجاح! 🚀', 'success');

            // Remove from local state
            const removedDev = STATE.devices.find(d => d.id === deviceId);
            STATE.devices = STATE.devices.filter(d => d.id !== deviceId);
            if (removedDev && removedDev.child_id) {
                STATE.children = STATE.children.filter(c => c.id !== removedDev.child_id);
            } else if (childId) {
                STATE.children = STATE.children.filter(c => c.id !== childId);
            }

            if (STATE.activeDeviceId === deviceId || STATE.activeChildId === childId) {
                if (STATE.children.length > 0) {
                    const nextChild = STATE.children[0];
                    const nextDev = STATE.devices.find(d => d.child_id === nextChild.id);
                    App.selectChild(nextChild.id, nextDev ? nextDev.id : '');
                } else {
                    STATE.activeDeviceId = null;
                    STATE.activeChildId = null;
                    localStorage.removeItem('active_device_id');
                    localStorage.removeItem('active_child_id');
                    App.updateActiveDeviceUI();
                }
            }
        }

        closeModal('deleteDeviceModal');
        App.renderChildrenCards();
        App.loadStats();
    } catch (e) {
        console.error('Failed to delete device/child:', e);
        UI.showToast('فشل الحذف: ' + e.message, 'error');
    } finally {
        if (btn) {
            btn.disabled = false;
            btn.innerHTML = originalBtnHtml;
        }
    }
}

window.openDeleteDeviceModal = openDeleteDeviceModal;
window.openDeleteChildModal = openDeleteChildModal;
window.executeDeviceCompleteDeletion = executeDeviceCompleteDeletion;

// Start Application on Load
window.addEventListener('DOMContentLoaded', () => App.init());
window.App = App;
window.fetchDeviceNotifications = () => App.loadNotifications();
