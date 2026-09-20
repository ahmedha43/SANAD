<?php
/**
 * Dashboard Stats Cards Component
 */
declare(strict_types=1);
?>
<section class="stats-grid">
    <!-- Card 1: Active Device & Status -->
    <div class="stat-card">
        <div class="stat-icon cyan">
            <i class="fa-solid fa-mobile-screen"></i>
        </div>
        <div class="stat-details">
            <span class="stat-label">حالة الجهاز النشط</span>
            <div class="stat-value" id="cardDeviceStatus">متصل الآن</div>
            <span class="stat-sub" id="cardDeviceModel">TECNO KL7</span>
        </div>
    </div>

    <!-- Card 2: Battery Level -->
    <div class="stat-card">
        <div class="stat-icon emerald">
            <i class="fa-solid fa-battery-three-quarters" id="cardBatteryIcon"></i>
        </div>
        <div class="stat-details">
            <span class="stat-label">مستوى البطارية</span>
            <div class="stat-value" id="cardBatteryLevel">--%</div>
            <span class="stat-sub" id="cardBatteryStatus">آخر تحديث: قبل قليل</span>
        </div>
    </div>

    <!-- Card 3: Screen Time Usage -->
    <div class="stat-card">
        <div class="stat-icon purple">
            <i class="fa-solid fa-clock"></i>
        </div>
        <div class="stat-details">
            <span class="stat-label">وقت الشاشة اليوم</span>
            <div class="stat-value" id="cardScreenTime">-- دقيقة</div>
            <span class="stat-sub" id="cardScreenTimeLimit">الحد اليومي: 120 دقيقة</span>
        </div>
    </div>

    <!-- Card 4: AI Risk Alert Level -->
    <div class="stat-card">
        <div class="stat-icon amber">
            <i class="fa-solid fa-shield-check" id="cardRiskIcon"></i>
        </div>
        <div class="stat-details">
            <span class="stat-label">درجة الأمان والحماية</span>
            <div class="stat-value" id="cardRiskStatus">آمن تماماً</div>
            <span class="stat-sub" id="cardRiskCount">0 مخاطر مرصودة</span>
        </div>
    </div>
</section>
