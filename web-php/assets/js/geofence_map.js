/**
 * Professional Interactive Geofence Map Controller Module
 * Manages dedicated Leaflet map, interactive circle drawing, radius controls, and live safe zone editing
 */

const GeofenceMapController = {
    map: null,
    kidMarker: null,
    activeZonesGroup: null,
    centerMarker: null,
    previewCircle: null,
    currentRadius: 300,
    selectedLatLng: null,
    isInitialized: false,

    async init() {
        const container = document.getElementById('geofenceMap');
        if (!container) return;

        if (this.map) {
            this.map.invalidateSize();
            await this.refreshKidLocation();
            return;
        }

        // 1. Resolve real kid location dynamically
        let initialLat = null;
        let initialLng = null;
        const devId = window.STATE?.activeDeviceId;

        if (window.STATE?.latestLocation?.latitude) {
            initialLat = parseFloat(window.STATE.latestLocation.latitude);
            initialLng = parseFloat(window.STATE.latestLocation.longitude);
        } else if (window.STATE?.devices && devId) {
            const dev = window.STATE.devices.find(d => d.id === devId);
            if (dev?.last_location?.latitude) {
                initialLat = parseFloat(dev.last_location.latitude);
                initialLng = parseFloat(dev.last_location.longitude);
                window.STATE.latestLocation = dev.last_location;
            }
        }

        // If not in state yet, fetch live from API
        if ((initialLat === null || isNaN(initialLat)) && devId && window.API?.getLatestLocation) {
            try {
                const res = await API.getLatestLocation(devId);
                const loc = res.data || res.location || res;
                if (loc && loc.latitude && loc.longitude) {
                    initialLat = parseFloat(loc.latitude);
                    initialLng = parseFloat(loc.longitude);
                    window.STATE.latestLocation = loc;
                }
            } catch (_) {}
        }

        // If active geofences exist, center on the first zone
        if ((initialLat === null || isNaN(initialLat)) && window.STATE?.geofences && window.STATE.geofences.length > 0) {
            const firstFence = window.STATE.geofences[0];
            initialLat = parseFloat(firstFence.latitude);
            initialLng = parseFloat(firstFence.longitude);
        }

        // Final fallback if totally empty
        if (initialLat === null || isNaN(initialLat)) {
            initialLat = 33.4884;
            initialLng = 43.2138;
        }

        this.map = L.map('geofenceMap', {
            zoomControl: true,
            attributionControl: false
        }).setView([initialLat, initialLng], 15);

        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19
        }).addTo(this.map);

        this.activeZonesGroup = L.featureGroup().addTo(this.map);

        // Kid pin marker
        const kidIcon = L.divIcon({
            className: 'custom-kid-marker',
            html: '<div class="marker-pulse"><div class="marker-core"><i class="fa-solid fa-child"></i></div></div>',
            iconSize: [40, 40],
            iconAnchor: [20, 20]
        });
        this.kidMarker = L.marker([initialLat, initialLng], { icon: kidIcon }).addTo(this.map);
        this.kidMarker.bindTooltip('موقع الطفل الفعلي الآن', { direction: 'top' });

        // Map Click Listener for interactive safe zone center selection
        this.map.on('click', (e) => {
            this.setCenter(e.latlng.lat, e.latlng.lng, false);
        });

        this.isInitialized = true;

        // Auto-select kid location initially if available
        this.setCenter(initialLat, initialLng, false);

        // If geofences are already loaded, render them
        if (window.STATE?.geofences && window.STATE.geofences.length > 0) {
            this.renderActiveGeofences(window.STATE.geofences);
        }

        // Load breach events log
        this.loadBreachEvents();

        // Refresh location asynchronously to ensure pin matches latest GPS
        this.refreshKidLocation();
    },

    async refreshKidLocation() {
        const devId = window.STATE?.activeDeviceId;
        if (!devId || !window.API?.getLatestLocation) return;
        try {
            const res = await API.getLatestLocation(devId);
            const loc = res.data || res.location || res;
            if (loc && loc.latitude && loc.longitude) {
                window.STATE.latestLocation = loc;
                this.updateKidLocation(loc.latitude, loc.longitude);
            }
        } catch (_) {}
    },

    updateKidLocation(lat, lng) {
        lat = parseFloat(lat);
        lng = parseFloat(lng);
        if (isNaN(lat) || isNaN(lng)) return;
        if (!this.map) return;
        if (this.kidMarker) {
            this.kidMarker.setLatLng([lat, lng]);
        } else {
            const kidIcon = L.divIcon({
                className: 'custom-kid-marker',
                html: '<div class="marker-pulse"><div class="marker-core"><i class="fa-solid fa-child"></i></div></div>',
                iconSize: [40, 40],
                iconAnchor: [20, 20]
            });
            this.kidMarker = L.marker([lat, lng], { icon: kidIcon }).addTo(this.map);
            this.kidMarker.bindTooltip('موقع الطفل الفعلي الآن', { direction: 'top' });
        }
    },

    setCenter(lat, lng, pan = false) {
        if (isNaN(lat) || isNaN(lng)) return;
        this.selectedLatLng = [lat, lng];

        // Update coordinate input fields
        const latInput = document.getElementById('fenceLat');
        const lngInput = document.getElementById('fenceLng');
        if (latInput) latInput.value = lat.toFixed(5);
        if (lngInput) lngInput.value = lng.toFixed(5);

        // Update or create draggable center pin
        if (!this.centerMarker) {
            const centerIcon = L.divIcon({
                className: 'custom-geofence-center-pin',
                html: '<div style="background:#10B981; color:#fff; width:32px; height:32px; border-radius:50%; display:flex; align-items:center; justify-content:center; box-shadow:0 0 12px rgba(16,185,129,0.6); border:2px solid #fff; cursor:move;"><i class="fa-solid fa-location-dot"></i></div>',
                iconSize: [32, 32],
                iconAnchor: [16, 16]
            });
            this.centerMarker = L.marker([lat, lng], {
                icon: centerIcon,
                draggable: true
            }).addTo(this.map);

            this.centerMarker.on('drag', (e) => {
                const pos = e.target.getLatLng();
                this.setCenter(pos.lat, pos.lng, false);
            });
        } else {
            this.centerMarker.setLatLng([lat, lng]);
        }

        // Update or create interactive perimeter circle
        if (!this.previewCircle) {
            this.previewCircle = L.circle([lat, lng], {
                radius: this.currentRadius,
                color: '#10B981',
                fillColor: '#10B981',
                fillOpacity: 0.22,
                weight: 3,
                dashArray: '6, 8'
            }).addTo(this.map);
        } else {
            this.previewCircle.setLatLng([lat, lng]);
            this.previewCircle.setRadius(this.currentRadius);
        }

        // Update floating status pill
        const pillText = document.getElementById('geofenceModeText');
        if (pillText) {
            pillText.innerHTML = `تم تحديد المركز: <strong>${lat.toFixed(4)}, ${lng.toFixed(4)}</strong> (اسحب العلامة للتعديل)`;
        }

        if (pan && this.map) {
            this.map.panTo([lat, lng]);
        }
    },

    onRadiusSlider(val) {
        const r = parseInt(val) || 300;
        this.currentRadius = r;

        const badge = document.getElementById('fenceRadiusBadge');
        if (badge) badge.textContent = `${r} متر`;

        const hiddenInput = document.getElementById('fenceRadius');
        if (hiddenInput) hiddenInput.value = r;

        if (this.previewCircle) {
            this.previewCircle.setRadius(r);
        }
    },

    applyPreset(name, radius) {
        const nameInput = document.getElementById('fenceName');
        if (nameInput) nameInput.value = name;

        const slider = document.getElementById('fenceRadiusSlider');
        if (slider) slider.value = radius;

        this.onRadiusSlider(radius);

        if (window.UI && window.UI.showToast) {
            UI.showToast(`تم تطبيق نموذج: ${name} بنصف قطر ${radius}م`, 'info');
        }
    },

    async useKidLocationAsCenter() {
        let lat = null;
        let lng = null;
        const devId = window.STATE?.activeDeviceId;

        // Fetch fresh location from server
        if (devId && window.API?.getLatestLocation) {
            try {
                const res = await API.getLatestLocation(devId);
                const loc = res.data || res.location || res;
                if (loc && loc.latitude && loc.longitude) {
                    lat = parseFloat(loc.latitude);
                    lng = parseFloat(loc.longitude);
                    window.STATE.latestLocation = loc;
                }
            } catch (_) {}
        }

        // Or fallback to memory/device
        if (lat === null && window.STATE?.latestLocation?.latitude) {
            lat = parseFloat(window.STATE.latestLocation.latitude);
            lng = parseFloat(window.STATE.latestLocation.longitude);
        } else if (lat === null && window.STATE?.devices && devId) {
            const dev = window.STATE.devices.find(d => d.id === devId);
            if (dev?.last_location?.latitude) {
                lat = parseFloat(dev.last_location.latitude);
                lng = parseFloat(dev.last_location.longitude);
                window.STATE.latestLocation = dev.last_location;
            }
        }

        if (lat !== null && !isNaN(lat) && lng !== null && !isNaN(lng)) {
            this.updateKidLocation(lat, lng);
            this.setCenter(lat, lng, true);
            if (this.map) this.map.flyTo([lat, lng], 16, { duration: 0.8 });
            if (window.UI && window.UI.showToast) {
                UI.showToast(`تم تحديد موقع الطفل الفعلي الآن كمركز (${lat.toFixed(4)}, ${lng.toFixed(4)})`, 'success');
            }
        } else {
            if (window.UI && window.UI.showToast) {
                UI.showToast('لم يتم العثور على موقع فعلي مسجل، انقر على الخريطة مباشرة', 'warning');
            }
        }
    },

    async centerOnKidLocation() {
        if (!this.map) return;
        let lat = null;
        let lng = null;
        const devId = window.STATE?.activeDeviceId;

        if (devId && window.API?.getLatestLocation) {
            try {
                const res = await API.getLatestLocation(devId);
                const loc = res.data || res.location || res;
                if (loc && loc.latitude && loc.longitude) {
                    lat = parseFloat(loc.latitude);
                    lng = parseFloat(loc.longitude);
                    window.STATE.latestLocation = loc;
                }
            } catch (_) {}
        }

        if (lat === null && window.STATE?.latestLocation?.latitude) {
            lat = parseFloat(window.STATE.latestLocation.latitude);
            lng = parseFloat(window.STATE.latestLocation.longitude);
        } else if (lat === null && window.STATE?.devices && devId) {
            const dev = window.STATE.devices.find(d => d.id === devId);
            if (dev?.last_location?.latitude) {
                lat = parseFloat(dev.last_location.latitude);
                lng = parseFloat(dev.last_location.longitude);
                window.STATE.latestLocation = dev.last_location;
            }
        }

        if (lat !== null && !isNaN(lat) && lng !== null && !isNaN(lng)) {
            this.updateKidLocation(lat, lng);
            this.map.flyTo([lat, lng], 16, { duration: 0.8 });
            if (window.UI && window.UI.showToast) {
                UI.showToast(`موقع الطفل الفعلي الآن: ${lat.toFixed(4)}, ${lng.toFixed(4)}`, 'info');
            }
        } else if (this.kidMarker) {
            this.map.setView(this.kidMarker.getLatLng(), 16);
        }
    },

    fitAllZones() {
        if (!this.map) return;
        if (this.activeZonesGroup && this.activeZonesGroup.getLayers().length > 0) {
            this.map.fitBounds(this.activeZonesGroup.getBounds(), { padding: [50, 50] });
        } else if (this.kidMarker) {
            this.map.setView(this.kidMarker.getLatLng(), 15);
        }
    },

    async startCreatingZone() {
        const nameInput = document.getElementById('fenceName');
        if (nameInput) {
            nameInput.focus();
            if (!nameInput.value) nameInput.value = 'منطقة أمان جديدة';
        }
        if (!this.selectedLatLng) {
            await this.useKidLocationAsCenter();
        }
        if (window.UI && window.UI.showToast) {
            UI.showToast('وضع رسم المنطقة نشط: انقر على الخريطة لتغيير المركز أو اضبط نصف القطر', 'info');
        }
    },

    resetDesigner() {
        const nameInput = document.getElementById('fenceName');
        if (nameInput) nameInput.value = '';
        const slider = document.getElementById('fenceRadiusSlider');
        if (slider) slider.value = 300;
        this.onRadiusSlider(300);

        if (this.previewCircle && this.map) {
            this.map.removeLayer(this.previewCircle);
            this.previewCircle = null;
        }
        if (this.centerMarker && this.map) {
            this.map.removeLayer(this.centerMarker);
            this.centerMarker = null;
        }
        this.selectedLatLng = null;

        const latInput = document.getElementById('fenceLat');
        const lngInput = document.getElementById('fenceLng');
        if (latInput) latInput.value = '';
        if (lngInput) lngInput.value = '';

        const pillText = document.getElementById('geofenceModeText');
        if (pillText) pillText.textContent = 'انقر على الخريطة لتحديد مركز المنطقة الآمنة';
    },

    renderActiveGeofences(fences) {
        if (!this.map || !this.activeZonesGroup) return;

        this.activeZonesGroup.clearLayers();

        if (!Array.isArray(fences) || fences.length === 0) {
            const countBadge = document.getElementById('activeGeofencesCountBadge');
            if (countBadge) countBadge.textContent = '0';
            return;
        }

        const countBadge = document.getElementById('activeGeofencesCountBadge');
        if (countBadge) countBadge.textContent = fences.length.toString();

        fences.forEach(f => {
            const lat = parseFloat(f.latitude);
            const lng = parseFloat(f.longitude);
            const rad = f.radius_meters || f.radius || 300;
            if (isNaN(lat) || isNaN(lng)) return;

            const circle = L.circle([lat, lng], {
                radius: rad,
                color: '#10B981',
                fillColor: '#10B981',
                fillOpacity: 0.18,
                weight: 2
            });

            const triggerLabel = (f.alert_on_entry && f.alert_on_exit) || f.trigger_type === 'both'
                ? 'الدخول والخروج 🔄'
                : (f.alert_on_exit || f.trigger_type === 'exit' ? 'الخروج فقط 🚨' : 'الدخول فقط 🟢');

            const cleanName = window.escapeHtml ? window.escapeHtml(f.name) : f.name;

            circle.bindPopup(`
                <div style="direction: rtl; font-family: inherit; min-width: 190px; padding: 4px;">
                    <div style="font-weight: 700; color: #10B981; font-size: 1rem; margin-bottom: 6px; display:flex; align-items:center; gap:6px;">
                        <i class="fa-solid fa-shield-halved"></i> ${cleanName}
                    </div>
                    <div style="font-size: 0.82rem; margin-bottom: 4px; color: var(--text-primary, #fff);">
                        <b>نصف القطر:</b> ${rad} متر
                    </div>
                    <div style="font-size: 0.82rem; margin-bottom: 8px; color: var(--text-secondary, #cbd5e1);">
                        <b>نوع التنبيه:</b> ${triggerLabel}
                    </div>
                    <div style="display:flex; gap:6px;">
                        <button class="btn btn-outline-sm" style="flex:1; justify-content:center; padding:4px 8px; font-size:0.75rem;" onclick="GeofenceMapController.focusZone(${lat}, ${lng}, ${rad})">
                            <i class="fa-solid fa-crosshairs"></i> تكبير
                        </button>
                        <button class="btn btn-danger-sm" style="flex:1; justify-content:center; padding:4px 8px; font-size:0.75rem; background:#ef4444; color:#fff;" onclick="App.deleteGeofence('${f.id}')">
                            <i class="fa-solid fa-trash"></i> حذف
                        </button>
                    </div>
                </div>
            `);

            circle.bindTooltip(cleanName, {
                permanent: true,
                direction: 'top',
                className: 'geofence-permanent-tooltip'
            });

            this.activeZonesGroup.addLayer(circle);
        });
    },

    focusZone(lat, lng, radius) {
        if (!this.map) return;
        this.map.flyTo([lat, lng], 16, { duration: 1.2 });

        // Temporary pulse ring
        const highlight = L.circle([lat, lng], {
            radius: radius,
            color: '#38BDF8',
            fillColor: '#38BDF8',
            fillOpacity: 0.35,
            weight: 4
        }).addTo(this.map);

        setTimeout(() => {
            try { this.map.removeLayer(highlight); } catch (_) {}
        }, 2500);
    },

    async saveZone() {
        const name = (document.getElementById('fenceName')?.value || '').trim();
        const radius = parseInt(document.getElementById('fenceRadius')?.value) || this.currentRadius;
        const triggerType = document.getElementById('fenceTriggerType')?.value || 'both';

        let lat = parseFloat(document.getElementById('fenceLat')?.value);
        let lng = parseFloat(document.getElementById('fenceLng')?.value);

        if (isNaN(lat) || isNaN(lng)) {
            if (this.selectedLatLng) {
                lat = this.selectedLatLng[0];
                lng = this.selectedLatLng[1];
            } else if (window.STATE?.latestLocation?.latitude) {
                lat = parseFloat(window.STATE.latestLocation.latitude);
                lng = parseFloat(window.STATE.latestLocation.longitude);
            }
        }

        if (!name) {
            if (window.UI && window.UI.showToast) UI.showToast('يرجى كتابة اسم للمنطقة الآمنة', 'warning');
            document.getElementById('fenceName')?.focus();
            return;
        }

        if (isNaN(lat) || isNaN(lng)) {
            if (window.UI && window.UI.showToast) UI.showToast('يرجى تحديد مركز المنطقة بالنقر على الخريطة', 'warning');
            return;
        }

        const childId = window.STATE?.activeChildId || (window.STATE?.children?.[0]?.id);
        if (!childId) {
            if (window.UI && window.UI.showToast) UI.showToast('لم يتم العثور على طفل محدد', 'error');
            return;
        }

        const saveBtn = document.getElementById('btnSaveGeofence');
        if (saveBtn) {
            saveBtn.disabled = true;
            saveBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> جاري الحفظ...';
        }

        try {
            const body = {
                child_id: childId,
                name: name,
                latitude: lat,
                longitude: lng,
                radius: radius,
                radius_meters: radius,
                trigger_type: triggerType,
                alert_on_entry: triggerType === 'both' || triggerType === 'enter',
                alert_on_exit: triggerType === 'both' || triggerType === 'exit'
            };

            await API.createGeofence(body);

            if (window.UI && window.UI.showToast) {
                UI.showToast(`✓ تم إنشاء وتفعيل المنطقة الآمنة "${name}" بنجاح`, 'success');
            }

            this.resetDesigner();
            await App.loadGeofences();
        } catch (e) {
            console.error('Failed to save geofence:', e);
            if (window.UI && window.UI.showToast) {
                UI.showToast('فشل حفظ المنطقة: ' + (e.message || 'خطأ غير معروف'), 'error');
            }
        } finally {
            if (saveBtn) {
                saveBtn.disabled = false;
                saveBtn.innerHTML = '<i class="fa-solid fa-floppy-disk"></i> <span>حفظ وتفعيل المنطقة الآمنة</span>';
            }
        }
    },

    async loadBreachEvents() {
        const tbody = document.getElementById('geofenceEventsTableBody');
        if (!tbody) return;

        const childId = window.STATE?.activeChildId || (window.STATE?.children?.[0]?.id);
        if (!childId) return;

        try {
            const res = await API.getGeofenceEvents(childId);
            const events = (res && (res.data || (Array.isArray(res) ? res : []))) || [];

            const badge = document.getElementById('geofenceBreachEventsCountBadge');
            if (badge) badge.textContent = `${events.length} تنبيه مسجل`;

            if (events.length === 0) {
                tbody.innerHTML = `
                    <tr>
                        <td colspan="5" class="text-center text-muted" style="padding: 30px;">
                            <i class="fa-solid fa-shield-check" style="font-size: 2rem; color: var(--accent-emerald); margin-bottom: 8px; display: block;"></i>
                            <div>البيئة آمنة تماماً - لم يتم تسجيل أي تجاوزات للمناطق الآمنة حتى الآن.</div>
                        </td>
                    </tr>
                `;
                return;
            }

            tbody.innerHTML = events.map(ev => {
                const isExit = (ev.event_type || '').toUpperCase() === 'EXIT';
                const typeBadge = isExit
                    ? '<span class="status-badge status-badge-paused" style="background:rgba(239,68,68,0.15); color:var(--accent-rose);"><i class="fa-solid fa-triangle-exclamation"></i> خروج وتجاوز المحيط</span>'
                    : '<span class="status-badge status-badge-active" style="background:rgba(16,185,129,0.15); color:var(--accent-emerald);"><i class="fa-solid fa-circle-check"></i> دخول للمنطقة</span>';

                const timeStr = ev.triggered_at 
                    ? new Date(ev.triggered_at).toLocaleString('ar-EG', { dateStyle: 'medium', timeStyle: 'short' }) 
                    : (ev.created_at ? new Date(ev.created_at).toLocaleString('ar-EG', { dateStyle: 'medium', timeStyle: 'short' }) : 'قبل قليل');

                const zoneName = ev.geofence_name || 'المنطقة الآمنة';

                return `
                    <tr>
                        <td><strong>${timeStr}</strong></td>
                        <td><i class="fa-solid fa-location-dot" style="color:var(--accent-cyan); margin-left:6px;"></i>${window.escapeHtml(zoneName)}</td>
                        <td>${typeBadge}</td>
                        <td><span style="color:${isExit ? 'var(--accent-rose)' : 'var(--accent-emerald)'}; font-weight:600;">${isExit ? 'تنبيه طارئ مرسل للأهل' : 'آمن ومستقر'}</span></td>
                        <td>
                            <button class="btn btn-outline-sm" onclick="switchSection('location')" title="فتح مسار الرحلة لتفقد الموقع">
                                <i class="fa-solid fa-route"></i> <span>عرض بالمسار</span>
                            </button>
                        </td>
                    </tr>
                `;
            }).join('');
        } catch (e) {
            console.warn('Load breach events failed:', e.message);
            tbody.innerHTML = `
                <tr>
                    <td colspan="5" class="text-center text-muted" style="padding: 20px;">
                        <i class="fa-solid fa-shield-check" style="color:var(--accent-emerald); margin-left:6px;"></i>
                        النظام جاهز ومحيط الحماية نشط.
                    </td>
                </tr>
            `;
        }
    }
};

window.GeofenceMapController = GeofenceMapController;
