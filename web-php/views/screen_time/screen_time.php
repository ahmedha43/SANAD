<?php
/**
 * Screen Time & Bedtime Limits Component
 */
declare(strict_types=1);
?>
<section class="panel-card" id="screenTimeSection">
    <div class="panel-card-header">
        <div class="panel-title-group">
            <i class="fa-solid fa-hourglass-half" style="color: var(--accent-amber)"></i>
            <div>
                <h3>قواعد وقت الشاشة وموعد النوم (Screen Time & Bedtime)</h3>
                <span class="sub-text">تنظيم ساعات استخدام الجهاز اليومية وقفل الجهاز تلقائياً أثناء وقت النوم والدراسة</span>
            </div>
        </div>
        <button class="btn btn-amber-sm" onclick="saveScreenTimeSettings()">
            <i class="fa-solid fa-floppy-disk"></i>
            <span>حفظ القواعد وتطبيقها فوراً</span>
        </button>
    </div>

    <div class="dashboard-grid-2col">
        <!-- Settings Form -->
        <div class="card-inner">
            <h4 class="card-subtitle"><i class="fa-solid fa-sliders"></i> ضبط الحدود اليومية</h4>
            
            <div class="form-group" style="margin-top: 15px;">
                <div class="slider-label-row">
                    <label>الحد الأقصى للاستخدام اليومي:</label>
                    <span class="slider-value-badge" id="dailyLimitMinutesLabel">120 دقيقة (ساعتان)</span>
                </div>
                <input type="range" id="dailyLimitSlider" min="30" max="480" step="15" value="120" class="time-slider" oninput="updateDailyLimitLabel(this.value)">
            </div>

            <div class="form-grid-2" style="margin-top: 20px;">
                <div class="form-group">
                    <label><i class="fa-solid fa-bed"></i> بداية وقت النوم (حظر الجهاز):</label>
                    <input type="time" id="bedtimeStartInput" value="22:00" class="form-input">
                </div>
                <div class="form-group">
                    <label><i class="fa-solid fa-sun"></i> نهاية وقت النوم (إلغاء الحظر):</label>
                    <input type="time" id="bedtimeEndInput" value="07:00" class="form-input">
                </div>
            </div>

            <div class="checkbox-group" style="margin-top: 15px;">
                <label class="custom-checkbox">
                    <input type="checkbox" id="bedtimeEnabledCheck" checked>
                    <span class="checkmark"></span>
                    <span class="checkbox-text">تفعيل جدول وقت النوم وقفل الجهاز ليلاً تلقائياً</span>
                </label>
            </div>
        </div>

        <!-- Usage Analytics Chart -->
        <div class="card-inner">
            <h4 class="card-subtitle"><i class="fa-solid fa-chart-pie"></i> تقرير استهلاك التطبيقات لليوم</h4>
            <div class="chart-container" style="position: relative; height: 220px; width: 100%; margin-top: 10px;">
                <canvas id="screenTimeUsageChart"></canvas>
            </div>
            <div class="top-apps-list" id="topAppsUsageList">
                <div class="text-center text-muted" style="padding: 10px;">جاري تحليل استهلاك التطبيقات...</div>
            </div>
        </div>
    </div>
</section>
