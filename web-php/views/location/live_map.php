<?php
/**
 * Live GPS Map Component
 */
declare(strict_types=1);
?>
<section class="panel-card" id="mapSection">
    <div class="panel-card-header">
        <div class="panel-title-group">
            <i class="fa-solid fa-map-location-dot" style="color: var(--accent-cyan)"></i>
            <div>
                <h3>التتبع الجغرافي الحي (Live GPS Tracking)</h3>
                <span class="sub-text" id="mapLastFixTime">آخر إحداثيات مستلمة: قبل قليل</span>
            </div>
        </div>
        <div class="header-actions">
            <button class="btn btn-outline-sm" onclick="recenterMap()" title="توسيط الخريطة على موقع الطفل">
                <i class="fa-solid fa-crosshairs"></i>
                <span>توسيط</span>
            </button>
            <button class="btn btn-cyan-sm" onclick="toggleRouteReplayPanel()">
                <i class="fa-solid fa-clock-rotate-left"></i>
                <span>مسار 24 ساعة</span>
            </button>
        </div>
    </div>

    <!-- Map Container -->
    <div class="map-wrapper">
        <div id="liveMap" class="leaflet-map-view"></div>
        <div class="map-overlay-info" id="mapOverlayInfo">
            <div class="overlay-item">
                <span class="overlay-label">السرعة:</span>
                <span class="overlay-val" id="gpsSpeed">0 كم/س</span>
            </div>
            <div class="overlay-item">
                <span class="overlay-label">الدقة:</span>
                <span class="overlay-val" id="gpsAccuracy">±5 متر</span>
            </div>
            <div class="overlay-item">
                <span class="overlay-label">العنوان التقريبي:</span>
                <span class="overlay-val" id="gpsAddress">جاري التحديد...</span>
            </div>
        </div>
    </div>
</section>
