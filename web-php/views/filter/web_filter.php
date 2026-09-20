<?php
/**
 * Web Filter & Safe Browsing Management Component
 */
declare(strict_types=1);
?>
<section class="panel-card" id="webFilterSection">
    <div class="panel-card-header">
        <div class="panel-title-group">
            <i class="fa-solid fa-globe" style="color: var(--accent-cyan)"></i>
            <div>
                <h3>تصفية وفحص محتوى الويب والمتصفحات (Web Filtering & SafeSearch)</h3>
                <span class="sub-text">محرك فحص وحماية ذكي للمتصفحات، وحظر الكلمات البذيئة والبحث غير اللائق والمواقع الضارة لحظياً</span>
            </div>
        </div>
        <div style="display: flex; gap: 8px;">
            <button class="btn btn-outline-sm" onclick="loadWebFilter(true)">
                <i class="fa-solid fa-arrows-rotate"></i>
                <span>تحديث القواعد</span>
            </button>
            <button class="btn btn-emerald-sm" onclick="seedWebFilterDefaults()">
                <i class="fa-solid fa-bolt-lightning"></i>
                <span>تحميل القوائم الذكية الافتراضية</span>
            </button>
            <button class="btn btn-primary-sm" onclick="openAddWebFilterModal()">
                <i class="fa-solid fa-plus"></i>
                <span>إضافة كلمة أو رابط</span>
            </button>
        </div>
    </div>

    <!-- Master Web Filter Engine Toggle Banner -->
    <div class="master-monitoring-banner" id="webFilterEngineBanner" style="margin-bottom: 20px;">
        <div class="master-monitoring-info">
            <div class="master-icon-wrap active" id="webFilterEngineIcon">
                <i class="fa-solid fa-globe"></i>
            </div>
            <div class="master-text-block">
                <div class="master-title-row">
                    <h4 id="webFilterEngineTitle">محرك تصفية الويب نشط بالكامل</h4>
                    <span class="status-badge status-badge-active" id="webFilterEngineBadge">نشط 🟢</span>
                </div>
                <p class="master-subtitle" id="webFilterEngineDesc">
                    يتم فحص المتصفحات لحظياً لمنع البحث غير اللائق وتصفح المواقع المحظورة وإغلاقها فوراً مع حماية الطفل.
                </p>
            </div>
        </div>
        <button class="btn-master-toggle btn-master-pause" id="btnToggleWebFilterEngine" onclick="toggleWebFilterEngine()">
            <i class="fa-solid fa-power-off" id="webFilterEngineBtnIcon"></i>
            <span id="webFilterEngineBtnText">إيقاف محرك الويب</span>
        </button>
    </div>

    <!-- Toolbar: Filters, Batch Controls & Search -->
    <div class="table-toolbar" style="flex-wrap: wrap; gap: 12px;">
        <div class="filter-pills">
            <button class="filter-pill active" onclick="filterWebRules('all', this)">الكل (<span id="countAllWebRules">0</span>)</button>
            <button class="filter-pill" onclick="filterWebRules('keyword', this)">كلمات البحث (<span id="countWebKeywords">0</span>)</button>
            <button class="filter-pill" onclick="filterWebRules('domain', this)">روابط ومواقع (<span id="countWebDomains">0</span>)</button>
            <button class="filter-pill" onclick="filterWebRules('adult', this)">إباحية (<span id="countWebAdult">0</span>)</button>
            <button class="filter-pill" onclick="filterWebRules('gambling', this)">قمار ومراهنات (<span id="countWebGambling">0</span>)</button>
            <button class="filter-pill" onclick="filterWebRules('drugs', this)">مخدرات (<span id="countWebDrugs">0</span>)</button>
            <button class="filter-pill" onclick="filterWebRules('bypass', this)">بروكسي وحجب (<span id="countWebBypass">0</span>)</button>
        </div>

        <div style="display: flex; gap: 8px; align-items: center; margin-right: auto;">
            <button class="btn btn-outline-xs" onclick="toggleAllWebFilterRules(true)">
                <i class="fa-solid fa-check-double"></i> تفعيل الكل
            </button>
            <button class="btn btn-outline-xs text-danger" onclick="toggleAllWebFilterRules(false)">
                <i class="fa-solid fa-ban"></i> إيقاف الكل
            </button>
            <div class="search-input-wrapper">
                <i class="fa-solid fa-magnifying-glass"></i>
                <input type="text" id="webFilterSearchInput" placeholder="بحث في الكلمات أو الروابط..." oninput="searchWebRules(this.value)" class="search-input">
            </div>
        </div>
    </div>

    <!-- Web Filter Rules Table -->
    <div class="table-responsive">
        <table class="modern-table">
            <thead>
                <tr>
                    <th style="width: 50px;">#</th>
                    <th>النوع</th>
                    <th>الكلمة أو الرابط المحظور</th>
                    <th>التصنيف</th>
                    <th>تاريخ الإضافة</th>
                    <th>الحالة</th>
                    <th style="width: 100px; text-align: center;">تشغيل/إيقاف</th>
                    <th style="width: 80px; text-align: center;">حذف</th>
                </tr>
            </thead>
            <tbody id="webFilterTableBody">
                <tr>
                    <td colspan="8" class="text-center text-muted">جاري تحميل قواعد تصفية الويب...</td>
                </tr>
            </tbody>
        </table>
    </div>
</section>

<!-- Modal: Add Web Filter Rule -->
<div class="modal-backdrop" id="addWebFilterModal" style="display: none;">
    <div class="modal-dialog">
        <div class="modal-header">
            <h3><i class="fa-solid fa-shield-halved text-cyan"></i> إضافة كلمة أو رابط للحظر</h3>
            <button class="modal-close" onclick="closeAddWebFilterModal()">&times;</button>
        </div>
        <div class="modal-body">
            <form id="addWebFilterForm" onsubmit="submitAddWebFilterRule(event)">
                <div class="form-group">
                    <label>نوع القاعدة:</label>
                    <div style="display: flex; gap: 16px; margin-top: 6px;">
                        <label style="cursor: pointer; display: flex; align-items: center; gap: 6px;">
                            <input type="radio" name="rule_type" value="keyword" checked>
                            <span>🔤 كلمة بحث أو نص (Keyword)</span>
                        </label>
                        <label style="cursor: pointer; display: flex; align-items: center; gap: 6px;">
                            <input type="radio" name="rule_type" value="domain">
                            <span>🌐 رابط أو موقع ويب (Domain/URL)</span>
                        </label>
                    </div>
                </div>

                <div class="form-group" style="margin-top: 14px;">
                    <label id="rulePatternLabel">الكلمة أو النص المحظور:</label>
                    <input type="text" id="rulePatternInput" class="form-control" placeholder="مثال: قمار أو badword أو site.com" required>
                    <span class="field-hint" id="rulePatternHint">سيتم حظر أي بحث أو صفحة تحتوي على هذه الكلمة أو مرادفاتها العربية.</span>
                </div>

                <div class="form-group" style="margin-top: 14px;">
                    <label>التصنيف:</label>
                    <select id="ruleCategorySelect" class="form-control">
                        <option value="adult">🔞 محتوى إباحي وغير لائق (Adult)</option>
                        <option value="gambling">🎰 قمار ومراهنات (Gambling)</option>
                        <option value="drugs">💊 مخدرات وكحول (Drugs)</option>
                        <option value="violence">⚔️ عنف وانتحار وسلاح (Violence)</option>
                        <option value="bypass">🛡️ بروكسي ومواقع كسر الحجب (Bypass/Proxy)</option>
                        <option value="custom" selected>⚙️ مخصص (Custom)</option>
                    </select>
                </div>

                <div class="modal-footer" style="margin-top: 20px; display: flex; justify-content: flex-end; gap: 8px;">
                    <button type="button" class="btn btn-secondary" onclick="closeAddWebFilterModal()">إلغاء</button>
                    <button type="submit" class="btn btn-primary" id="btnSubmitAddWebFilter">
                        <i class="fa-solid fa-check"></i> إضافة وحفظ
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>
