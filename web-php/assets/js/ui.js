/**
 * UI Controller Module
 * Handles Modals, Tabs, Section Navigation, Toasts, and State Presentation
 */

const UI = {
    // === Navigation / Sections ===
    // === Feature Gating Helpers ===
    hasFeature(featureSlug) {
        if (!window.STATE?.subscription) return true;
        const sub = window.STATE.subscription;
        const tier = sub.tier || '';
        if (tier === 'family_unlimited' || tier === 'unlimited') return true;
        const feats = sub.features || [];
        return feats.includes(featureSlug);
    },

    showFeatureLockedModal(sectionId, featureSlug) {
        const featureNames = {
            'live-stream': 'بث الكاميرا والصوت المباشر (WebRTC Live Stream)',
            'geofences': 'المناطق الجغرافية الآمنة (Geofencing)',
            'apps': 'إدارة وحظر التطبيقات عن بُعد (App Blocker)',
            'screen-time': 'جدولة وقت الشاشة وموعد النوم (Screen Time)',
            'contacts': 'سجل جهات الاتصال (Contacts)',
            'notifications': 'إشعارات التطبيقات الملتقطة (App Notifications)',
            'gallery': 'معرض الصور والملفات (Media Gallery)',
            'alerts': 'فحص المخاطر الذكي والـ SOS (Smart AI Risk)',
            'screenshot': 'لقطة الشاشة الصامتة الفورية (Silent Screenshot)',
            'live-screen': 'عرض وبث شاشة الطفل المباشر (Live Screen Mirroring)'
        };

        const titleEl = document.getElementById('lockedFeatureTitle');
        const descEl = document.getElementById('lockedFeatureDesc');
        const currentPlanEl = document.getElementById('lockedCurrentPlanName');

        const featName = featureNames[sectionId] || featureNames[featureSlug] || featureSlug;
        const currentPlan = window.STATE?.subscription?.plan_name || 'الباقة المجانية';

        if (titleEl) titleEl.textContent = `ميزة مقفلة: ${featName}`;
        if (currentPlanEl) currentPlanEl.textContent = currentPlan;
        if (descEl) {
            descEl.innerHTML = `هذه الميزة غير مشمولة في باقتك الحالية (<strong class="text-info">${currentPlan}</strong>). يرجى الترقية إلى باقة أعلى للوصول إليها.`;
        }

        this.openModal('featureLockedModal');
    },

    // === Navigation / Sections ===
    switchSection(sectionId, clickedEl = null) {
        // Feature Gating Check
        const featureMap = {
            'live-stream': 'live_camera',
            'live-screen': 'live_camera',
            'geofences': 'geofencing',
            'apps': 'app_blocking',
            'screen-time': 'screen_time',
            'contacts': 'contacts',
            'notifications': 'notifications',
            'gallery': 'media_gallery',
            'alerts': 'ai_risk_detection'
        };

        const requiredFeat = featureMap[sectionId];
        if (requiredFeat && !this.hasFeature(requiredFeat)) {
            this.showFeatureLockedModal(sectionId, requiredFeat);
            return;
        }

        // Hide all sections
        document.querySelectorAll('.content-section').forEach(sec => sec.style.display = 'none');
        
        // Show target section
        const target = document.getElementById(`section-${sectionId}`);
        if (target) target.style.display = 'block';

        // Update sidebar active item
        document.querySelectorAll('.sidebar .nav-item').forEach(item => item.classList.remove('active'));
        if (clickedEl) {
            clickedEl.classList.add('active');
        } else {
            const match = document.querySelector(`.sidebar a[href="#${sectionId}"]`);
            if (match) match.classList.add('active');
        }

        // Section-specific initializations & data loading
        if (sectionId === 'location') {
            const mapSection = document.getElementById('mapSection');
            const routePanel = document.getElementById('routeReplayPanel');
            const locHolder = document.getElementById('locationSectionHolder') || document.getElementById('section-location');
            if (mapSection && locHolder) {
                locHolder.appendChild(mapSection);
                if (routePanel) locHolder.appendChild(routePanel);
            }
            setTimeout(() => {
                if (window.MapController && window.MapController.map) window.MapController.map.invalidateSize();
            }, 200);
        } else if (sectionId === 'overview') {
            const mapSection = document.getElementById('mapSection');
            const routePanel = document.getElementById('routeReplayPanel');
            const overviewMapCol = document.getElementById('overviewMapCol');
            if (mapSection && overviewMapCol) {
                overviewMapCol.appendChild(mapSection);
                if (routePanel) overviewMapCol.appendChild(routePanel);
            }
            setTimeout(() => {
                if (window.MapController && window.MapController.map) window.MapController.map.invalidateSize();
            }, 200);
        } else if (sectionId === 'calls') {
            if (window.App && window.App.loadCalls) window.App.loadCalls();
        } else if (sectionId === 'apps') {
            if (window.App && window.App.loadApps) window.App.loadApps();
        } else if (sectionId === 'sms') {
            if (window.App && window.App.loadSMS) window.App.loadSMS();
        } else if (sectionId === 'contacts') {
            if (window.App && window.App.loadContacts) window.App.loadContacts();
        } else if (sectionId === 'notifications') {
            if (window.App && window.App.loadNotifications) window.App.loadNotifications();
        } else if (sectionId === 'gallery') {
            if (window.App && window.App.loadFiles) window.App.loadFiles();
        } else if (sectionId === 'alerts') {
            if (window.App && window.App.loadRiskAlerts) window.App.loadRiskAlerts();
        } else if (sectionId === 'screen-time') {
            if (window.App && window.App.loadScreenTimeRules) window.App.loadScreenTimeRules();
        } else if (sectionId === 'web-filter') {
            if (window.loadWebFilter) window.loadWebFilter();
        } else if (sectionId === 'browser-history') {
            if (window.loadBrowserHistory) window.loadBrowserHistory();
        } else if (sectionId === 'geofences') {
            if (window.GeofenceMapController) {
                window.GeofenceMapController.init();
                if (window.GeofenceMapController.refreshKidLocation) {
                    window.GeofenceMapController.refreshKidLocation();
                }
            }
            if (window.App && window.App.loadGeofences) {
                window.App.loadGeofences();
            }
            setTimeout(() => {
                if (window.GeofenceMapController && window.GeofenceMapController.map) {
                    window.GeofenceMapController.map.invalidateSize();
                }
                if (window.MapController && window.MapController.map) {
                    window.MapController.map.invalidateSize();
                }
            }, 250);
        }

        // Close sidebar on mobile
        if (window.innerWidth <= 992) {
            document.getElementById('appSidebar')?.classList.remove('open');
        }
    },

    // === Modals ===
    openModal(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.style.display = 'flex';
            document.body.style.overflow = 'hidden';
        }
    },

    closeModal(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.style.display = 'none';
            document.body.style.overflow = 'auto';
        }
    },

    // === Toasts ===
    showToast(message, type = 'info', duration = 4000) {
        const container = document.getElementById('toastContainer');
        if (!container) return;

        const toast = document.createElement('div');
        toast.className = `toast-item toast-${type}`;
        
        const icons = {
            info: 'fa-circle-info',
            success: 'fa-circle-check',
            warning: 'fa-triangle-exclamation',
            error: 'fa-circle-xmark'
        };

        toast.innerHTML = `
            <i class="fa-solid ${icons[type] || 'fa-bell'}"></i>
            <div class="toast-text">${message}</div>
            <button class="toast-close" onclick="this.parentElement.remove()">✕</button>
        `;

        container.appendChild(toast);
        setTimeout(() => toast.classList.add('visible'), 10);

        setTimeout(() => {
            toast.classList.remove('visible');
            setTimeout(() => toast.remove(), 300);
        }, duration);
    },

    // === Connection Status ===
    setWsStatus(status) {
        const dot = document.getElementById('wsPulseDot');
        const text = document.getElementById('wsStatusText');
        if (!dot || !text) return;

        dot.className = 'status-pulse-dot ' + status;
        if (status === 'connected') {
            text.textContent = 'متصل بالسيرفر';
            dot.style.background = 'var(--accent-emerald)';
        } else if (status === 'disconnected') {
            text.textContent = 'انقطع الاتصال';
            dot.style.background = 'var(--accent-rose)';
        } else {
            text.textContent = 'جاري المزامنة...';
            dot.style.background = 'var(--accent-amber)';
        }
    },

    updateDeviceOnlineStatus(isOnline, battery = null) {
        const statusEl = document.getElementById('cardDeviceStatus');
        const sideDot = document.getElementById('sideOnlineDot');
        const sideText = document.getElementById('sideOnlineText');
        const battEl = document.getElementById('cardBatteryLevel');
        const sideBatt = document.getElementById('sideBatteryText');

        if (statusEl) {
            statusEl.textContent = isOnline ? 'متصل الآن' : 'غير متصل';
            statusEl.style.color = isOnline ? 'var(--accent-emerald)' : 'var(--text-muted)';
        }
        if (sideDot) sideDot.className = isOnline ? 'online-indicator active' : 'online-indicator';
        if (sideText) sideText.textContent = isOnline ? 'متصل' : 'غير متصل';

        if (battery !== null && battery !== undefined) {
            if (battEl) battEl.textContent = battery + '%';
            if (sideBatt) sideBatt.textContent = battery + '%';
        }
    },

    // === Screenshot Modal ===
    displayScreenshot(base64Data) {
        if (window._screenshotWatchdog) {
            clearTimeout(window._screenshotWatchdog);
            window._screenshotWatchdog = null;
        }
        if (!base64Data) {
            this.displayScreenshotError('لم يتم استلام بيانات صورة صالحة');
            return;
        }
        const img = document.getElementById('screenshotModalImage');
        const loader = document.getElementById('screenshotLoading');
        const errBox = document.getElementById('screenshotError');
        const downloadBtn = document.getElementById('screenshotDownloadBtn');
        const timeEl = document.getElementById('screenshotCaptureTime');

        const src = base64Data.startsWith('data:image') ? base64Data : `data:image/jpeg;base64,${base64Data}`;
        
        if (loader) loader.style.display = 'none';
        if (errBox) errBox.style.display = 'none';
        if (img) {
            img.src = src;
            img.style.display = 'block';
        }
        if (downloadBtn) {
            downloadBtn.href = src;
            downloadBtn.style.display = 'inline-flex';
        }
        if (timeEl) timeEl.textContent = 'الوقت: ' + new Date().toLocaleTimeString('ar-EG');

        this.openModal('screenshotModal');
        this.showToast('تم التقاط لقطة الشاشة بنجاح', 'success');
    },

    displayScreenshotError(errorMsg) {
        if (window._screenshotWatchdog) {
            clearTimeout(window._screenshotWatchdog);
            window._screenshotWatchdog = null;
        }
        const loader = document.getElementById('screenshotLoading');
        const img = document.getElementById('screenshotModalImage');
        const errBox = document.getElementById('screenshotError');
        const errText = document.getElementById('screenshotErrorText');
        const downloadBtn = document.getElementById('screenshotDownloadBtn');

        if (loader) loader.style.display = 'none';
        if (img) img.style.display = 'none';
        if (downloadBtn) downloadBtn.style.display = 'none';
        if (errBox) {
            errBox.style.display = 'block';
            if (errText) errText.textContent = errorMsg || 'تعذر التقاط لقطة الشاشة من هاتف الطفل';
        }

        this.openModal('screenshotModal');
        this.showToast(errorMsg || 'فشل التقاط لقطة الشاشة', 'error');
    },

    // === Media Modal Preview ===
    openMediaPreview(url, title = 'صورة') {
        const img = document.getElementById('mediaModalImage');
        const titleEl = document.getElementById('mediaModalTitle');
        const downloadBtn = document.getElementById('mediaModalDownloadBtn');
        const metaEl = document.getElementById('mediaModalMeta');

        if (img) img.src = url;
        if (titleEl) titleEl.querySelector('span').textContent = title;
        if (downloadBtn) downloadBtn.href = url;
        if (metaEl) metaEl.textContent = title;

        this.openModal('mediaModal');
    },

    // === Subscription Expired Modal & Quota UI ===
    showSubscriptionExpiredModal(data = {}) {
        const title = document.getElementById('subModalTitle');
        const msg = document.getElementById('subModalStatusMsg');
        const statusBadge = document.getElementById('subModalStatusBadge');
        if (title) title.textContent = 'تم إيقاف الميزات مؤقتاً';
        if (msg) msg.textContent = data.message || 'انتهت صلاحية باقة اشتراكك، يرجى تجديد الترخيص لمتابعة خدمات الحماية والرعاية';
        if (statusBadge) {
            statusBadge.className = 'badge bg-danger';
            statusBadge.textContent = 'منتهي الصلاحية';
        }
        this.openModal('subscriptionModal');
    },

    updateSubscriptionUI(sub) {
        if (!sub) return;
        const banner = document.getElementById('subscriptionAlertBanner');
        const quotaBar = document.getElementById('subscriptionQuotaBar');
        const quotaPlan = document.getElementById('quotaPlanName');
        const quotaDevices = document.getElementById('quotaDevicesUsed');
        const quotaExpiry = document.getElementById('quotaExpiryDate');

        // Modal fields
        const modalPlan = document.getElementById('subModalPlan');
        const modalStatus = document.getElementById('subModalStatusBadge');
        const modalDevices = document.getElementById('subModalDevices');
        const modalExpiry = document.getElementById('subModalExpiry');

        if (quotaPlan) quotaPlan.textContent = sub.plan_name || sub.tier;
        if (quotaDevices) quotaDevices.textContent = `${sub.used_devices || 0} / ${sub.max_devices || 0}`;
        
        let expiryFormatted = 'مدى الحياة';
        if (sub.expires_at) {
            const d = new Date(sub.expires_at);
            expiryFormatted = d.toLocaleDateString('ar-EG');
        }
        if (quotaExpiry) quotaExpiry.textContent = expiryFormatted;
        if (quotaBar) quotaBar.style.display = 'flex';

        if (modalPlan) modalPlan.textContent = sub.plan_name || sub.tier;
        if (modalDevices) modalDevices.textContent = `${sub.used_devices || 0} / ${sub.max_devices || 0}`;
        if (modalExpiry) modalExpiry.textContent = expiryFormatted;

        if (sub.is_expired || sub.status !== 'active') {
            if (banner) banner.style.display = 'flex';
            if (modalStatus) {
                modalStatus.className = 'badge bg-danger';
                modalStatus.textContent = sub.is_expired ? 'منتهي الصلاحية' : 'معلق';
            }
            // Disable remote action buttons
            document.querySelectorAll('.btn-remote-action, #btnPairKidDevice, .btn-live-stream').forEach(btn => {
                btn.classList.add('disabled');
                btn.setAttribute('title', 'تم تعطيل هذه الميزة لانتهاء صلاحية الاشتراك');
            });
        } else {
            if (banner) banner.style.display = 'none';
            if (modalStatus) {
                modalStatus.className = 'badge bg-success';
                modalStatus.textContent = 'فعال';
            }
        }

        // Feature Gating: Lock sidebar badges and quick action buttons
        const featureMap = {
            'live-stream': 'live_camera',
            'geofences': 'geofencing',
            'apps': 'app_blocking',
            'screen-time': 'screen_time',
            'contacts': 'contacts',
            'notifications': 'notifications',
            'gallery': 'media_gallery',
            'alerts': 'ai_risk_detection'
        };

        Object.entries(featureMap).forEach(([secId, featKey]) => {
            const link = document.querySelector(`.sidebar a[href="#${secId}"]`);
            if (link) {
                const existingBadge = link.querySelector('.nav-badge.locked-feature');
                if (!this.hasFeature(featKey)) {
                    if (!existingBadge) {
                        const badge = document.createElement('span');
                        badge.className = 'nav-badge locked-feature';
                        badge.innerHTML = '<i class="fa-solid fa-lock"></i> VIP';
                        badge.style.background = 'rgba(245, 158, 11, 0.2)';
                        badge.style.color = '#f59e0b';
                        badge.style.border = '1px solid rgba(245, 158, 11, 0.4)';
                        link.appendChild(badge);
                    }
                } else if (existingBadge) {
                    existingBadge.remove();
                }
            }
        });

        // Quick Actions lock indicator
        const screenshotBtn = document.querySelector('button[onclick="requestScreenshot()"]');
        if (screenshotBtn) {
            if (!this.hasFeature('silent_screenshot')) {
                screenshotBtn.classList.add('feature-locked');
                screenshotBtn.setAttribute('title', 'ميزة لقطة الشاشة متاحة في الباقة المتقدمة فقط');
            } else {
                screenshotBtn.classList.remove('feature-locked');
            }
        }

        const antiUninstallBtn = document.getElementById('btnAntiUninstall');
        if (antiUninstallBtn) {
            if (!this.hasFeature('anti_uninstall')) {
                antiUninstallBtn.classList.add('feature-locked');
                antiUninstallBtn.setAttribute('title', 'ميزة منع إزالة التطبيق متاحة في الباقة المتقدمة فقط');
            } else {
                antiUninstallBtn.classList.remove('feature-locked');
            }
        }

        const stealthBtn = document.getElementById('btnStealthMode');
        if (stealthBtn) {
            if (!this.hasFeature('stealth_mode')) {
                stealthBtn.classList.add('feature-locked');
                stealthBtn.setAttribute('title', 'ميزة وضع التخفي متاحة في الباقة المتقدمة فقط');
            } else {
                stealthBtn.classList.remove('feature-locked');
            }
        }

        const blockSettingsBtn = document.getElementById('btnBlockSettings');
        if (blockSettingsBtn) {
            if (!this.hasFeature('settings_protection')) {
                blockSettingsBtn.classList.add('feature-locked');
                blockSettingsBtn.setAttribute('title', 'ميزة حظر إعدادات الهاتف متاحة في الباقة المتقدمة فقط');
            } else {
                blockSettingsBtn.classList.remove('feature-locked');
            }
        }
    }
};

// Global shortcuts
function switchSection(id, el) { UI.switchSection(id, el); }
function openModal(id) { UI.openModal(id); }
function closeModal(id) { UI.closeModal(id); }
function toggleSidebar() {
    document.getElementById('appSidebar')?.classList.toggle('open');
}
function togglePassVisibility(inputId) {
    const input = document.getElementById(inputId);
    if (!input) return;
    input.type = input.type === 'password' ? 'text' : 'password';
}

window.UI = UI;
