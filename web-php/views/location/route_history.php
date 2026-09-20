<?php
/**
 * 24-Hour Route Replay Component
 */
declare(strict_types=1);
?>
<div class="route-replay-panel" id="routeReplayPanel" style="display: none;">
    <div class="replay-header">
        <div class="replay-title">
            <i class="fa-solid fa-route"></i>
            <span>إعادة تشغيل مسار الرحلات (Route Replay)</span>
        </div>
        <button class="close-replay-btn" onclick="toggleRouteReplayPanel()">✕</button>
    </div>

    <!-- Safe Zone Perimeter Breach Alert Banner in Route History -->
    <div class="route-breach-summary-bar" id="routeBreachSummaryBar" style="display: none;">
        <div style="display: flex; align-items: center; gap: 10px;">
            <i class="fa-solid fa-triangle-exclamation" style="color: var(--accent-rose); font-size: 1.2rem;"></i>
            <div>
                <strong style="color: var(--accent-rose);">رصد تجاوزات للمناطق الآمنة:</strong>
                <span id="routeBreachCountText" style="color: var(--text-primary); font-size: 0.88rem; margin-right: 6px;">تم تسجيل خروج عن محيط الأمان</span>
            </div>
        </div>
        <div id="routeBreachChipsContainer" style="display: flex; gap: 6px; flex-wrap: wrap;"></div>
    </div>

    <div class="replay-controls-row">
        <button class="replay-btn play" id="btnPlayRoute" onclick="toggleRoutePlayback()">
            <i class="fa-solid fa-play" id="playRouteIcon"></i>
        </button>

        <div class="replay-slider-container">
            <input type="range" id="routeTimeSlider" min="0" max="100" value="0" class="time-slider" oninput="onRouteSliderChange(this.value)">
            <div class="slider-timestamps">
                <span id="replayStartTime">منذ 24 ساعة</span>
                <span id="replayCurrentPointTime">اختر نقطة...</span>
                <span id="replayEndTime">الآن</span>
            </div>
        </div>

        <div class="speed-selector">
            <label>السرعة:</label>
            <select id="replaySpeedSelect" onchange="changeReplaySpeed(this.value)" class="form-select-sm">
                <option value="1">1x</option>
                <option value="2" selected>2x</option>
                <option value="5">5x</option>
                <option value="10">10x</option>
            </select>
        </div>
    </div>
</div>
