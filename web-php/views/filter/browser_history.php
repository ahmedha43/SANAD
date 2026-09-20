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
            <i class="fa-solid fa-clock-rotate-left" style="color: var(--accent-cyan); font-size: 1.4rem;"></i>
            <div>
                <h3 style="display: flex; align-items: center; gap: 8px;">
                    <span>مستكشف سجل التصفح السحابي والبحث الآمن</span>
                    <span class="nav-badge" style="background: linear-gradient(135deg, #06b6d4, #3b82f6); font-size: 0.7rem;">DEEP MONITORING</span>
                </h3>
                <span class="sub-text">مراقبة الروابط والمواقع المزارة في (Chrome و Edge و Firefox) والكلمات المبحوث عنها في Google و YouTube مع حظر فوري</span>
            </div>
        </div>
        <div style="display: flex; gap: 8px; align-items: center;">
            <button class="btn btn-outline-sm" onclick="loadBrowserHistory(true)" title="تحديث السجل من السيرفر">
                <i class="fa-solid fa-arrows-rotate" id="refreshHistoryIcon"></i>
                <span>تحديث السجل</span>
            </button>
            <button class="btn btn-outline-sm text-danger" onclick="confirmClearBrowserHistory()" title="مسح سجل التصفح لهذا الجهاز">
                <i class="fa-solid fa-trash-can"></i>
                <span>مسح السجل</span>
            </button>
        </div>
    </div>

    <!-- 4 Stats Cards for History Overview -->
    <div class="stats-grid" style="margin-bottom: 22px;">
        <div class="stat-card">
            <div class="stat-icon cyan">
                <i class="fa-solid fa-globe"></i>
            </div>
            <div class="stat-details">
                <span class="stat-label">عدد المواقع المزارة</span>
                <div class="stat-value" id="statHistoryTotalSites">0</div>
                <span class="stat-sub" id="statHistoryTodaySub">إجمالي صفحات الويب المفتوحة</span>
            </div>
        </div>

        <div class="stat-card">
            <div class="stat-icon purple">
                <i class="fa-solid fa-magnifying-glass"></i>
            </div>
            <div class="stat-details">
                <span class="stat-label">عدد عمليات البحث</span>
                <div class="stat-value" id="statHistoryTotalSearches">0</div>
                <span class="stat-sub">في Google و YouTube و Bing</span>
            </div>
        </div>

        <div class="stat-card">
            <div class="stat-icon amber">
                <i class="fa-solid fa-fire-flame-curved"></i>
            </div>
            <div class="stat-details">
                <span class="stat-label">أكثر المواقع زيارة</span>
                <div class="stat-value" id="statHistoryTopDomain" style="font-size: 1.15rem; font-weight: 700; color: #fbbf24; text-overflow: ellipsis; overflow: hidden; white-space: nowrap; max-width: 170px;">--</div>
                <span class="stat-sub" id="statHistoryTopDomainCount">لا توجد زيارات مسجلة</span>
            </div>
        </div>

        <div class="stat-card">
            <div class="stat-icon emerald">
                <i class="fa-solid fa-shield-halved"></i>
            </div>
            <div class="stat-details">
                <span class="stat-label">المتصفحات المراقبة والحظر</span>
                <div class="stat-value" style="font-size: 1.1rem; gap: 8px; display: flex; align-items: center;">
                    <i class="fa-brands fa-chrome" title="Google Chrome" style="color: #ea4335;"></i>
                    <i class="fa-brands fa-edge" title="Microsoft Edge" style="color: #0078d7;"></i>
                    <i class="fa-brands fa-firefox-browser" title="Mozilla Firefox" style="color: #ff7139;"></i>
                </div>
                <span class="stat-sub" id="statHistoryBlockedInfo">تم منع 0 محاولة محظورة</span>
            </div>
        </div>
    </div>

    <!-- Search Keywords Cloud: Radar for Google & YouTube Searches -->
    <div class="quick-actions-card" style="margin-bottom: 22px; background: rgba(13, 21, 38, 0.85); border: 1px solid rgba(139, 92, 246, 0.25); border-radius: 14px; padding: 16px 20px;">
        <div class="card-header-simple" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px;">
            <div style="display: flex; align-items: center; gap: 10px;">
                <div style="width: 34px; height: 34px; border-radius: 10px; background: rgba(139, 92, 246, 0.2); display: flex; align-items: center; justify-content: center; color: #a855f7;">
                    <i class="fa-brands fa-searchengin" style="font-size: 1.25rem;"></i>
                </div>
                <div>
                    <h4 style="margin: 0; font-size: 1.05rem; font-weight: 700; color: #f8fafc;">رادار كلمات البحث (Search Keywords Cloud)</h4>
                    <span style="font-size: 0.78rem; color: #94a3b8;">عرض مباشر لجميع عبارات البحث في Google و YouTube بشارات ملونة وأيقونات محركات البحث</span>
                </div>
            </div>
            <span class="nav-badge live" style="background: rgba(139, 92, 246, 0.25); color: #c084fc; border: 1px solid rgba(139, 92, 246, 0.4);">
                <i class="fa-solid fa-radar fa-spin"></i> رصد مباشر
            </span>
        </div>
        <div id="topSearchesContainer" style="display: flex; flex-wrap: wrap; gap: 10px; min-height: 42px; align-items: center;">
            <span class="text-muted" style="font-size: 0.85rem;">
                <i class="fa-solid fa-circle-notch fa-spin"></i> جاري تحميل رادار الكلمات المبحوث عنها...
            </span>
        </div>
    </div>

    <!-- Toolbar: Filters & Search -->
    <div class="table-toolbar" style="flex-wrap: wrap; gap: 12px; margin-bottom: 16px;">
        <div class="filter-pills">
            <button class="filter-pill active" onclick="filterBrowserHistory('all', this)">
                <i class="fa-solid fa-list-ul"></i> الكل (<span id="countAllHistory">0</span>)
            </button>
            <button class="filter-pill" onclick="filterBrowserHistory('searches', this)">
                <i class="fa-solid fa-magnifying-glass text-cyan"></i> عمليات البحث فقط 🔍 (<span id="countSearchesHistory">0</span>)
            </button>
            <button class="filter-pill" onclick="filterBrowserHistory('top-visited', this)">
                <i class="fa-solid fa-fire-flame-curved" style="color: #fbbf24;"></i> المواقع الأكثر تكراراً 📈
            </button>
            <button class="filter-pill" onclick="filterBrowserHistory('blocked', this)">
                <i class="fa-solid fa-ban text-danger"></i> المحظورة 🚫 (<span id="countBlockedHistory">0</span>)
            </button>
            <button class="filter-pill" onclick="filterBrowserHistory('chrome', this)">
                <i class="fa-brands fa-chrome" style="color: #ea4335;"></i> Chrome
            </button>
            <button class="filter-pill" onclick="filterBrowserHistory('edge', this)">
                <i class="fa-brands fa-edge" style="color: #0078d7;"></i> Edge
            </button>
            <button class="filter-pill" onclick="filterBrowserHistory('firefox', this)">
                <i class="fa-brands fa-firefox-browser" style="color: #ff7139;"></i> Firefox
            </button>
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
                    <th style="width: 45px;">#</th>
                    <th style="width: 110px;">المتصفح</th>
                    <th>عنوان الصفحة والموقع</th>
                    <th>الرابط / استعلام البحث</th>
                    <th style="width: 140px;">نوع النشاط</th>
                    <th style="width: 80px; text-align: center;">المرات</th>
                    <th style="width: 145px;">وقت وتاريخ الزيارة</th>
                    <th style="width: 95px; text-align: center;">الحالة</th>
                    <th style="width: 140px; text-align: center;">إجراء فوري</th>
                </tr>
            </thead>
            <tbody id="browserHistoryTableBody">
                <tr>
                    <td colspan="9" class="text-center text-muted" style="padding: 35px;">
                        <i class="fa-solid fa-circle-notch fa-spin"></i> جاري تحميل سجل التصفح والبحث...
                    </td>
                </tr>
            </tbody>
        </table>
    </div>
</section>
