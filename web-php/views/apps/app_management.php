<?php
/**
 * App Management & Remote Blocker Component
 */
declare(strict_types=1);
?>
<section class="panel-card" id="appsSection">
    <div class="panel-card-header">
        <div class="panel-title-group">
            <i class="fa-solid fa-cubes" style="color: var(--accent-purple)"></i>
            <div>
                <h3>إدارة وتطبيقات هاتف الطفل (App Management & Blocker)</h3>
                <span class="sub-text">التحكم الفوري في قفل وحظر التطبيقات المثبتة على جهاز الطفل بنقرة واحدة</span>
            </div>
        </div>
        <button class="btn btn-outline-sm" onclick="fetchDeviceApps(true)">
            <i class="fa-solid fa-arrows-rotate"></i>
            <span>تحديث التطبيقات</span>
        </button>
    </div>

    <!-- Filters & Search Toolbar -->
    <div class="table-toolbar">
        <div class="filter-pills">
            <button class="filter-pill active" onclick="filterApps('all', this)">الكل (<span id="countAllApps">0</span>)</button>
            <button class="filter-pill" onclick="filterApps('user', this)">تطبيقات المستخدم (<span id="countUserApps">0</span>)</button>
            <button class="filter-pill" onclick="filterApps('blocked', this)">المحظورة فقط (<span id="countBlockedApps">0</span>)</button>
            <button class="filter-pill" onclick="filterApps('system', this)">النظام (<span id="countSystemApps">0</span>)</button>
        </div>

        <div class="search-input-wrapper">
            <i class="fa-solid fa-magnifying-glass"></i>
            <input type="text" id="appSearchInput" placeholder="بحث باسم التطبيق أو الحزمة..." oninput="searchApps(this.value)" class="search-input">
        </div>
    </div>

    <!-- Apps Table -->
    <div class="table-responsive">
        <table class="modern-table">
            <thead>
                <tr>
                    <th style="width: 50px;">#</th>
                    <th>التطبيق</th>
                    <th>اسم الحزمة (Package)</th>
                    <th>النوع</th>
                    <th>الحالة</th>
                    <th style="width: 130px; text-align: center;">حظر فوري</th>
                </tr>
            </thead>
            <tbody id="appsTableBody">
                <tr>
                    <td colspan="6" class="text-center text-muted">جاري فحص التطبيقات المثبتة...</td>
                </tr>
            </tbody>
        </table>
    </div>
</section>
