<?php
/**
 * Cloud Browser History & Safe Search Explorer Component
 * مستكشف سجل التصفح السحابي وعمليات البحث الذكية
 */
declare(strict_types=1);
?>
<section class="panel-card" id="browserHistorySection">
    <div class="panel-card-header">
        <div class="panel-title-group">
            <i class="fa-solid fa-clock-rotate-left" style="color: var(--accent-cyan)"></i>
            <div>
                <h3>مستكشف سجل التصفح السحابي وعمليات البحث (Browser History & SafeSearch)</h3>
                <span class="sub-text">مراقبة الروابط والمواقع المزارة في (Chrome و Edge و Firefox) والكلمات المبحوث عنها في Google و YouTube مع حظر فوري</span>
            </div>
        </div>
        <div style="display: flex; gap: 8px; align-items: center;">
            <button class="btn btn-outline-sm" onclick="loadBrowserHistory(true)">
                <i class="fa-solid fa-arrows-rotate" id="refreshHistoryIcon"></i>
                <span>تحديث السجل</span>
            </button>
            <button class="btn btn-outline-sm text-danger" onclick="confirmClearBrowserHistory()">
                <i class="fa-solid fa-trash-can"></i>
                <span>مسح السجل</span>
            </button>
        </div>
    </div>

    <!-- 4 Stats Cards for History Overview -->
    <div class="stats-grid" style="margin-bottom: 20px;">
        <div class="stat-card">
            <div class="stat-icon cyan">
                <i class="fa-solid fa-globe"></i>
            </div>
            <div class="stat-details">
                <span class="stat-label">زيارات المواقع اليوم</span>
                <div class="stat-value" id="statHistoryTodayVisits">0</div>
                <span class="stat-sub">إجمالي صفحات الويب المفتوحة</span>
            </div>
        </div>

        <div class="stat-card">
            <div class="stat-icon purple">
                <i class="fa-solid fa-magnifying-glass"></i>
            </div>
            <div class="stat-details">
                <span class="stat-label">عمليات البحث المرصودة</span>
                <div class="stat-value" id="statHistoryTotalSearches">0</div>
                <span class="stat-sub">في Google و YouTube و Bing</span>
            </div>
        </div>

        <div class="stat-card">
            <div class="stat-icon amber">
                <i class="fa-solid fa-shield-halved"></i>
            </div>
            <div class="stat-details">
                <span class="stat-label">محاولات الدخول لمواقع محظورة</span>
                <div class="stat-value" id="statHistoryBlockedHits">0</div>
                <span class="stat-sub">تم اعتراضها ومنعها فورياً</span>
            </div>
        </div>

        <div class="stat-card">
            <div class="stat-icon emerald">
                <i class="fa-solid fa-window-restore"></i>
            </div>
            <div class="stat-details">
                <span class="stat-label">المتصفحات المراقبة</span>
                <div class="stat-value" style="font-size: 1.1rem; gap: 8px; display: flex; align-items: center;">
                    <i class="fa-brands fa-chrome" title="Chrome" style="color: #ea4335;"></i>
                    <i class="fa-brands fa-edge" title="Edge" style="color: #0078d7;"></i>
                    <i class="fa-brands fa-firefox-browser" title="Firefox" style="color: #ff7139;"></i>
                </div>
                <span class="stat-sub">مزامنة سحابية نشطة</span>
            </div>
        </div>
    </div>

    <!-- Top Searches Widget (Google & YouTube Highlights) -->
    <div class="quick-actions-card" style="margin-bottom: 20px; background: rgba(13, 21, 38, 0.85);">
        <div class="card-header-simple" style="margin-bottom: 12px;">
            <i class="fa-brands fa-searchengin" style="color: var(--accent-cyan); font-size: 1.2rem;"></i>
            <h4>أبرز ما بحث عنه الطفل في Google و YouTube (Search Intelligence Radar)</h4>
        </div>
        <div id="topSearchesContainer" style="display: flex; flex-wrap: wrap; gap: 10px;">
            <span class="text-muted" style="font-size: 0.85rem;">لا توجد عمليات بحث مسجلة حتى الآن.</span>
        </div>
    </div>

    <!-- Toolbar: Filters & Search -->
    <div class="table-toolbar" style="flex-wrap: wrap; gap: 12px; margin-bottom: 16px;">
        <div class="filter-pills">
            <button class="filter-pill active" onclick="filterBrowserHistory('all', this)">الكل (<span id="countAllHistory">0</span>)</button>
            <button class="filter-pill" onclick="filterBrowserHistory('searches', this)">عمليات البحث فقط 🔍 (<span id="countSearchesHistory">0</span>)</button>
            <button class="filter-pill" onclick="filterBrowserHistory('blocked', this)">المحظورة 🚫 (<span id="countBlockedHistory">0</span>)</button>
            <button class="filter-pill" onclick="filterBrowserHistory('chrome', this)"><i class="fa-brands fa-chrome"></i> Chrome</button>
            <button class="filter-pill" onclick="filterBrowserHistory('edge', this)"><i class="fa-brands fa-edge"></i> Edge</button>
            <button class="filter-pill" onclick="filterBrowserHistory('firefox', this)"><i class="fa-brands fa-firefox-browser"></i> Firefox</button>
        </div>

        <div style="display: flex; gap: 8px; align-items: center; margin-right: auto;">
            <div class="search-input-wrapper">
                <i class="fa-solid fa-magnifying-glass"></i>
                <input type="text" id="browserHistorySearchInput" placeholder="بحث في العناوين أو الروابط أو كلمات البحث..." oninput="debounceSearchHistory(this.value)" class="search-input">
            </div>
        </div>
    </div>

    <!-- Browsing History Interactive Table -->
    <div class="table-responsive">
        <table class="modern-table">
            <thead>
                <tr>
                    <th style="width: 50px;">#</th>
                    <th style="width: 100px;">المتصفح</th>
                    <th>عنوان الصفحة والموقع</th>
                    <th>الرابط / استعلام البحث</th>
                    <th style="width: 130px;">نوع النشاط</th>
                    <th style="width: 90px; text-align: center;">المرات</th>
                    <th style="width: 140px;">توقيت الزيارة</th>
                    <th style="width: 100px; text-align: center;">الحالة</th>
                    <th style="width: 130px; text-align: center;">إجراء فوري</th>
                </tr>
            </thead>
            <tbody id="browserHistoryTableBody">
                <tr>
                    <td colspan="9" class="text-center text-muted" style="padding: 30px;">
                        <i class="fa-solid fa-circle-notch fa-spin"></i> جاري تحميل سجل التصفح والبحث...
                    </td>
                </tr>
            </tbody>
        </table>
    </div>
</section>
