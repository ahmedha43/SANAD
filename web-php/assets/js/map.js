/**
 * Map & Geofence Controller Module
 * Handles Leaflet map rendering, live marker, geofence circles, 24h route replay,
 * and prominent safe zone perimeter breach detection & visualization.
 */

function haversineDistanceMeters(lat1, lon1, lat2, lon2) {
    const R = 6371e3;
    const phi1 = lat1 * Math.PI / 180;
    const phi2 = lat2 * Math.PI / 180;
    const deltaPhi = (lat2 - lat1) * Math.PI / 180;
    const deltaLambda = (lon2 - lon1) * Math.PI / 180;

    const a = Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
              Math.cos(phi1) * Math.cos(phi2) *
              Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

const MapController = {
    map: null,
    marker: null,
    routePolyline: null,
    breachPolylineGroup: null,
    breachMarkersGroup: null,
    geofenceCircles: [],
    activeGeofences: [],
    historyPoints: [],
    replayIndex: 0,
    replayTimer: null,
    replaySpeed: 2,
    isPlaying: false,

    init() {
        const container = document.getElementById('liveMap');
        if (!container || this.map) return;

        // Default view: Riyadh
        this.map = L.map('liveMap', { zoomControl: true }).setView([24.7136, 46.6753], 14);

        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '© OpenStreetMap contributors'
        }).addTo(this.map);

        // Feature groups for breach layers
        this.breachPolylineGroup = L.featureGroup().addTo(this.map);
        this.breachMarkersGroup = L.featureGroup().addTo(this.map);

        // Custom Kid Pin Marker
        const kidIcon = L.divIcon({
            className: 'custom-kid-marker',
            html: '<div class="marker-pulse"><div class="marker-core" id="liveKidMarkerCore"><i class="fa-solid fa-child"></i></div></div>',
            iconSize: [40, 40],
            iconAnchor: [20, 20]
        });

        this.marker = L.marker([24.7136, 46.6753], { icon: kidIcon }).addTo(this.map);
        this.routePolyline = L.polyline([], { color: '#06B6D4', weight: 4, opacity: 0.85 }).addTo(this.map);
    },

    updateLiveLocation(loc) {
        if (!loc || !loc.latitude || !loc.longitude) return;
        const lat = parseFloat(loc.latitude);
        const lng = parseFloat(loc.longitude);

        if (!this.map) this.init();

        const latLng = [lat, lng];
        if (this.marker) this.marker.setLatLng(latLng);

        // Update Overlay
        const speedEl = document.getElementById('gpsSpeed');
        const accEl = document.getElementById('gpsAccuracy');
        const fixTimeEl = document.getElementById('mapLastFixTime');

        if (speedEl) speedEl.textContent = (loc.speed ? Math.round(loc.speed * 3.6) : 0) + ' كم/س';
        if (accEl) accEl.textContent = `±${Math.round(loc.accuracy || 10)} متر`;
        if (fixTimeEl) fixTimeEl.textContent = 'آخر إحداثيات: الآن';

        // Add to breadcrumb trail
        if (this.routePolyline) {
            this.routePolyline.addLatLng(latLng);
        }
    },

    recenter() {
        if (this.map && this.marker) {
            this.map.setView(this.marker.getLatLng(), 16);
        }
    },

    async loadRouteHistory(hours = 24) {
        if (!window.STATE?.activeDeviceId) return;
        try {
            const data = await API.getLocationHistory(window.STATE.activeDeviceId, hours);
            const records = data.data || data.locations || data || [];
            if (!Array.isArray(records) || records.length === 0) {
                if (window.UI && window.UI.showToast) {
                    UI.showToast('لا توجد نقاط مسار مسجلة خلال هذه الفترة', 'info');
                }
                const breachBar = document.getElementById('routeBreachSummaryBar');
                if (breachBar) breachBar.style.display = 'none';
                return;
            }

            // Ensure active geofences are available for perimeter evaluation
            let fences = this.activeGeofences;
            if (!fences || fences.length === 0) {
                if (window.STATE?.geofences && window.STATE.geofences.length > 0) {
                    fences = window.STATE.geofences;
                    this.activeGeofences = fences;
                } else if (window.STATE?.activeChildId) {
                    try {
                        const gfRes = await API.getGeofences(window.STATE.activeChildId);
                        fences = (gfRes && (gfRes.data || gfRes.geofences || (Array.isArray(gfRes) ? gfRes : []))) || [];
                        this.activeGeofences = fences;
                        this.renderGeofences(fences);
                    } catch (_) {}
                }
            }

            // Parse raw points
            this.historyPoints = records.map(r => ({
                lat: parseFloat(r.latitude),
                lng: parseFloat(r.longitude),
                speed: r.speed ? Math.round(r.speed * 3.6) : 0,
                time: r.timestamp || r.created_at,
                isBreach: false,
                isExitBreachEvent: false,
                breachedZoneName: ''
            })).filter(p => !isNaN(p.lat) && !isNaN(p.lng));

            // Clear previous breach layers
            if (this.breachPolylineGroup) this.breachPolylineGroup.clearLayers();
            if (this.breachMarkersGroup) this.breachMarkersGroup.clearLayers();

            const breachEvents = [];
            let wasInside = true;

            // Evaluate points against active geofences
            if (fences && fences.length > 0) {
                this.historyPoints.forEach((pt, idx) => {
                    let insideAny = false;
                    let nearestZoneName = '';
                    let minDistance = Infinity;

                    fences.forEach(f => {
                        const fLat = parseFloat(f.latitude);
                        const fLng = parseFloat(f.longitude);
                        const fRad = f.radius_meters || f.radius || 300;
                        const dist = haversineDistanceMeters(pt.lat, pt.lng, fLat, fLng);

                        if (dist <= fRad) {
                            insideAny = true;
                            nearestZoneName = f.name;
                        }
                        if (dist < minDistance) {
                            minDistance = dist;
                            nearestZoneName = f.name;
                        }
                    });

                    pt.isBreach = !insideAny;
                    pt.breachedZoneName = nearestZoneName;

                    // Detect breach transition (inside -> outside)
                    if (!insideAny && wasInside && idx > 0) {
                        pt.isExitBreachEvent = true;
                        breachEvents.push({
                            index: idx,
                            lat: pt.lat,
                            lng: pt.lng,
                            time: pt.time,
                            speed: pt.speed,
                            zone: nearestZoneName,
                            distanceOutside: Math.round(minDistance)
                        });
                    }

                    wasInside = insideAny;
                });

                // Render Breach Segments (Polylines in Danger Red)
                let currentBreachSegment = [];
                this.historyPoints.forEach(pt => {
                    if (pt.isBreach) {
                        currentBreachSegment.push([pt.lat, pt.lng]);
                    } else {
                        if (currentBreachSegment.length > 1) {
                            L.polyline(currentBreachSegment, {
                                color: '#EF4444',
                                weight: 6,
                                opacity: 0.9,
                                dashArray: '6, 8',
                                lineCap: 'round'
                            }).addTo(this.breachPolylineGroup);
                        }
                        currentBreachSegment = [];
                    }
                });
                if (currentBreachSegment.length > 1) {
                    L.polyline(currentBreachSegment, {
                        color: '#EF4444',
                        weight: 6,
                        opacity: 0.9,
                        dashArray: '6, 8',
                        lineCap: 'round'
                    }).addTo(this.breachPolylineGroup);
                }

                // Place prominent Animated Warning Markers at breach moments
                breachEvents.forEach((ev) => {
                    const breachMarker = L.marker([ev.lat, ev.lng], {
                        icon: L.divIcon({
                            className: 'custom-breach-marker',
                            html: '<div class="breach-pin-pulse" title="تجاوز المنطقة الآمنة!"><i class="fa-solid fa-triangle-exclamation"></i></div>',
                            iconSize: [32, 32],
                            iconAnchor: [16, 16]
                        })
                    }).addTo(this.breachMarkersGroup);

                    const timeFormatted = ev.time ? new Date(ev.time).toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' }) : '';

                    breachMarker.bindPopup(`
                        <div style="direction: rtl; font-family: inherit; min-width: 210px; padding: 4px;">
                            <div style="color: #EF4444; font-weight: 700; font-size: 0.95rem; margin-bottom: 6px; display:flex; align-items:center; gap:6px;">
                                <i class="fa-solid fa-triangle-exclamation"></i> تجاوز محيط المنطقة الآمنة!
                            </div>
                            <div style="font-size: 0.83rem; margin-bottom: 3px; color: var(--text-primary, #fff);">
                                <b>المنطقة:</b> ${window.escapeHtml ? window.escapeHtml(ev.zone) : ev.zone}
                            </div>
                            <div style="font-size: 0.83rem; margin-bottom: 3px; color: var(--text-secondary, #cbd5e1);">
                                <b>التوقيت:</b> ${timeFormatted}
                            </div>
                            <div style="font-size: 0.83rem; margin-bottom: 6px; color: var(--text-secondary, #cbd5e1);">
                                <b>السرعة عند التجاوز:</b> ${ev.speed} كم/س
                            </div>
                            <button class="btn btn-warning-sm" style="width: 100%; justify-content: center; font-size: 0.75rem; padding: 3px 6px;" onclick="MapController.seekReplay(${ev.index})">
                                <i class="fa-solid fa-play"></i> إعادة تشغيل من نقطة التجاوز
                            </button>
                        </div>
                    `);
                });
            }

            // Render Safe / Main Polyline
            const latLngs = this.historyPoints.map(p => [p.lat, p.lng]);
            this.routePolyline.setLatLngs(latLngs);

            if (latLngs.length > 0) {
                this.map.fitBounds(this.routePolyline.getBounds(), { padding: [50, 50] });
            }

            // Update Breach Summary Banner in Route History Panel
            const breachBar = document.getElementById('routeBreachSummaryBar');
            const breachCountText = document.getElementById('routeBreachCountText');
            const chipsContainer = document.getElementById('routeBreachChipsContainer');

            if (breachBar) {
                if (breachEvents.length > 0) {
                    breachBar.style.display = 'flex';
                    if (breachCountText) {
                        breachCountText.textContent = `تم رصد ${breachEvents.length} حالة تجاوز للمناطق الآمنة خلال هذا المسار!`;
                    }
                    if (chipsContainer) {
                        chipsContainer.innerHTML = breachEvents.map((ev, i) => {
                            const timeStr = ev.time ? new Date(ev.time).toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' }) : '';
                            return `
                                <button type="button" class="breach-chip-btn" onclick="MapController.jumpToBreach(${ev.index}, ${ev.lat}, ${ev.lng})">
                                    <i class="fa-solid fa-triangle-exclamation"></i>
                                    <span>تجاوز ${i + 1}: ${timeStr} (${window.escapeHtml ? window.escapeHtml(ev.zone) : ev.zone})</span>
                                </button>
                            `;
                        }).join('');
                    }
                } else {
                    breachBar.style.display = 'none';
                }
            }

            // Init Slider
            const slider = document.getElementById('routeTimeSlider');
            if (slider) {
                slider.max = this.historyPoints.length - 1;
                slider.value = 0;
            }

            if (window.UI && window.UI.showToast) {
                if (breachEvents.length > 0) {
                    UI.showToast(`⚠️ تم رصد ${breachEvents.length} حالات تجاوز للمناطق الآمنة في تاريخ المسار`, 'warning', 6000);
                } else {
                    UI.showToast('تم تحميل مسار الرحلات - لم يُسجل أي تجاوز للنطاق الآمن 🟢', 'success');
                }
            }
        } catch (e) {
            console.error('Failed to load history:', e);
        }
    },

    jumpToBreach(index, lat, lng) {
        this.seekReplay(index);
        if (this.map) {
            this.map.flyTo([lat, lng], 17, { duration: 1 });
        }
    },

    toggleReplay() {
        if (this.isPlaying) {
            this.pauseReplay();
        } else {
            this.startReplay();
        }
    },

    startReplay() {
        if (this.historyPoints.length === 0) return;
        this.isPlaying = true;
        const icon = document.getElementById('playRouteIcon');
        if (icon) icon.className = 'fa-solid fa-pause';

        const step = () => {
            if (!this.isPlaying) return;
            if (this.replayIndex >= this.historyPoints.length) {
                this.pauseReplay();
                this.replayIndex = 0;
                return;
            }

            const pt = this.historyPoints[this.replayIndex];
            this.marker.setLatLng([pt.lat, pt.lng]);

            // Visual indicator on kid marker
            const core = document.getElementById('liveKidMarkerCore');
            if (core) {
                if (pt.isBreach) {
                    core.style.background = '#EF4444';
                    core.style.boxShadow = '0 0 16px rgba(239, 68, 68, 0.9)';
                } else {
                    core.style.background = '#06B6D4';
                    core.style.boxShadow = '0 0 10px rgba(6, 182, 212, 0.6)';
                }
            }

            const slider = document.getElementById('routeTimeSlider');
            if (slider) slider.value = this.replayIndex;

            const timeEl = document.getElementById('replayCurrentPointTime');
            if (timeEl && pt.time) {
                const d = new Date(pt.time);
                const timeFormatted = d.toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
                if (pt.isBreach) {
                    timeEl.innerHTML = `${timeFormatted} - <span style="color:#EF4444; font-weight:bold;">🚨 متجاوز للنطاق الآمن! (${pt.breachedZoneName})</span>`;
                } else {
                    timeEl.innerHTML = `${timeFormatted} - <span style="color:#10B981; font-weight:600;">🟢 داخل المحيط الآمن</span>`;
                }
            }

            this.replayIndex++;
            this.replayTimer = setTimeout(step, 1000 / this.replaySpeed);
        };

        step();
    },

    pauseReplay() {
        this.isPlaying = false;
        clearTimeout(this.replayTimer);
        const icon = document.getElementById('playRouteIcon');
        if (icon) icon.className = 'fa-solid fa-play';
    },

    seekReplay(index) {
        this.replayIndex = parseInt(index);
        if (this.historyPoints[this.replayIndex]) {
            const pt = this.historyPoints[this.replayIndex];
            this.marker.setLatLng([pt.lat, pt.lng]);

            // Visual indicator on kid marker
            const core = document.getElementById('liveKidMarkerCore');
            if (core) {
                if (pt.isBreach) {
                    core.style.background = '#EF4444';
                    core.style.boxShadow = '0 0 16px rgba(239, 68, 68, 0.9)';
                } else {
                    core.style.background = '#06B6D4';
                    core.style.boxShadow = '0 0 10px rgba(6, 182, 212, 0.6)';
                }
            }

            const timeEl = document.getElementById('replayCurrentPointTime');
            if (timeEl && pt.time) {
                const timeFormatted = new Date(pt.time).toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
                if (pt.isBreach) {
                    timeEl.innerHTML = `${timeFormatted} - <span style="color:#EF4444; font-weight:bold;">🚨 متجاوز للنطاق الآمن! (${pt.breachedZoneName})</span>`;
                } else {
                    timeEl.innerHTML = `${timeFormatted} - <span style="color:#10B981; font-weight:600;">🟢 داخل المحيط الآمن</span>`;
                }
            }
        }
    },

    renderGeofences(fences) {
        if (!this.map) return;
        this.activeGeofences = fences;

        // Clear previous
        this.geofenceCircles.forEach(c => {
            try { this.map.removeLayer(c); } catch (_) {}
        });
        this.geofenceCircles = [];

        if (!Array.isArray(fences)) return;

        fences.forEach(f => {
            const rad = f.radius_meters || f.radius || 300;
            const lat = parseFloat(f.latitude);
            const lng = parseFloat(f.longitude);
            if (isNaN(lat) || isNaN(lng)) return;

            const circle = L.circle([lat, lng], {
                radius: rad,
                color: '#10B981',
                fillColor: '#10B981',
                fillOpacity: 0.15,
                weight: 2,
                dashArray: '5, 8'
            }).addTo(this.map);

            const cleanName = window.escapeHtml ? window.escapeHtml(f.name) : f.name;
            circle.bindPopup(`<b>${cleanName}</b><br>محيط الأمان: ${rad} متر`);
            this.geofenceCircles.push(circle);
        });
    }
};

function recenterMap() { MapController.recenter(); }
function toggleRouteReplayPanel() {
    const p = document.getElementById('routeReplayPanel');
    if (!p) return;
    const isHidden = p.style.display === 'none';
    p.style.display = isHidden ? 'block' : 'none';
    if (isHidden) MapController.loadRouteHistory(24);
    else MapController.pauseReplay();
}
function toggleRoutePlayback() { MapController.toggleReplay(); }
function onRouteSliderChange(val) { MapController.seekReplay(val); }
function changeReplaySpeed(val) { MapController.replaySpeed = parseFloat(val) || 2; }

window.MapController = MapController;
