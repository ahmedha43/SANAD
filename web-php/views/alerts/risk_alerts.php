<?php
/**
 * AI Smart Risk & Threat Alerts Center Component
 */
declare(strict_types=1);
?>
<section class="panel-card" id="alertsSection">
    <div class="panel-card-header">
        <div class="panel-title-group">
            <i class="fa-solid fa-shield-virus" style="color: var(--accent-rose)"></i>
            <div>
                <h3>مركز تنبيهات المخاطر والتهديدات الذكية (Smart AI Risk & Threat Center)</h3>
                <span class="sub-text">رصد فوري متقدم بواسطة الذكاء الاصطناعي لمحادثات التنمر، المحتوى غير اللائق، الغرباء، واستغاثات الطوارئ</span>
            </div>
        </div>
        <div style="display: flex; gap: 8px;">
            <button class="btn btn-outline-sm" onclick="App.loadRiskAlerts(true)">
                <i class="fa-solid fa-arrows-rotate"></i>
                <span>تحديث التنبيهات</span>
            </button>
        </div>
    </div>

    <!-- AI Risk Summary KPI Cards -->
    <div class="stats-grid" style="padding: 16px 20px 0 20px; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 14px;">
        <div class="stat-card" style="padding: 14px;">
            <div class="stat-icon purple">
                <i class="fa-solid fa-shield-halved"></i>
            </div>
            <div class="stat-details">
                <span class="stat-label">إجمالي المخاطر المرصودة</span>
                <div class="stat-value" id="summaryTotalAlerts">0</div>
                <span class="stat-sub">كافة القنوات المتصلة</span>
            </div>
        </div>

        <div class="stat-card" style="padding: 14px;">
            <div class="stat-icon" style="background: rgba(239, 68, 68, 0.15); color: var(--accent-rose);">
                <i class="fa-solid fa-triangle-exclamation"></i>
            </div>
            <div class="stat-details">
                <span class="stat-label">محتوى غير لائق (Inappropriate)</span>
                <div class="stat-value" id="summaryInappropriateAlerts" style="color: var(--accent-rose);">0</div>
                <span class="stat-sub">كلمات أو وسائط مشبوهة</span>
            </div>
        </div>

        <div class="stat-card" style="padding: 14px;">
            <div class="stat-icon amber">
                <i class="fa-solid fa-user-secret"></i>
            </div>
            <div class="stat-details">
                <span class="stat-label">محادثات غرباء (Stranger)</span>
                <div class="stat-value" id="summaryStrangerAlerts" style="color: var(--accent-amber);">0</div>
                <span class="stat-sub">أرقام وجهات غير مسجلة</span>
            </div>
        </div>

        <div class="stat-card" style="padding: 14px;">
            <div class="stat-icon cyan">
                <i class="fa-solid fa-handshake-angle"></i>
            </div>
            <div class="stat-details">
                <span class="stat-label">تنمر واستغاثة (Bullying / SOS)</span>
                <div class="stat-value" id="summaryBullyingAlerts" style="color: var(--accent-cyan);">0</div>
                <span class="stat-sub">تهديدات مباشرة وطوارئ</span>
            </div>
        </div>
    </div>

    <!-- Toolbar: Filters & Search -->
    <div class="table-toolbar" style="padding: 16px 20px; flex-wrap: wrap; gap: 12px;">
        <div class="filter-pills" id="riskFilterPills">
            <button class="filter-pill active" onclick="App.filterRiskAlerts('all', this)">
                الكل (<span id="filterCountAll">0</span>)
            </button>
            <button class="filter-pill" onclick="App.filterRiskAlerts('INAPPROPRIATE', this)">
                🔞 محتوى غير لائق (<span id="filterCountInappropriate">0</span>)
            </button>
            <button class="filter-pill" onclick="App.filterRiskAlerts('STRANGER', this)">
                👤 محادثات غرباء (<span id="filterCountStranger">0</span>)
            </button>
            <button class="filter-pill" onclick="App.filterRiskAlerts('BULLYING', this)">
                🛑 تنمر إلكتروني (<span id="filterCountBullying">0</span>)
            </button>
            <button class="filter-pill" onclick="App.filterRiskAlerts('SOS', this)">
                🚨 استغاثات SOS (<span id="filterCountSOS">0</span>)
            </button>
            <button class="filter-pill" onclick="App.filterRiskAlerts('CRITICAL', this)">
                🔴 حرجة (<span id="filterCountCritical">0</span>)
            </button>
            <button class="filter-pill" onclick="App.filterRiskAlerts('HIGH', this)">
                🟠 مرتفعة (<span id="filterCountHigh">0</span>)
            </button>
        </div>

        <div class="search-box" style="min-width: 250px; flex: 1;">
            <i class="fa-solid fa-magnifying-glass"></i>
            <input type="text" id="searchRiskAlertsInput" placeholder="بحث في نصوص التنبيهات أو المصدر..." oninput="App.onRiskAlertSearch(this.value)" class="form-input">
        </div>
    </div>

    <!-- Risk Alert Items Stream -->
    <div class="alerts-stream-container" id="riskAlertsContainer" style="min-height: 250px;">
        <div class="text-center text-muted" style="padding: 50px;">
            <i class="fa-solid fa-spinner fa-spin" style="font-size: 2.2rem; color: var(--accent-rose); margin-bottom: 12px; display: block;"></i>
            <div>جاري تحميل وفحص تنبيهات المخاطر...</div>
        </div>
    </div>
</section>
