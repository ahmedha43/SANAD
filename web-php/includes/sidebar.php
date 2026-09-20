<?php
/**
 * Global Sidebar Navigation Component
 */
declare(strict_types=1);
?>
<aside class="sidebar" id="appSidebar">
    <div class="sidebar-menu">
        <div class="sidebar-category">الرئيسية والتحكم</div>
        
        <a href="#overview" class="nav-item active" onclick="switchSection('overview', this)">
            <i class="fa-solid fa-gauge-high"></i>
            <span>لوحة سَنَد العامة</span>
        </a>

        <a href="#live-stream" class="nav-item" onclick="switchSection('live-stream', this)">
            <i class="fa-solid fa-video"></i>
            <span>البث المباشر (الكاميرا والصوت)</span>
            <span class="nav-badge live">LIVE</span>
        </a>

        <a href="#live-screen" class="nav-item" onclick="switchSection('live-screen', this)">
            <i class="fa-solid fa-desktop"></i>
            <span>عرض وبث الشاشة المباشر</span>
            <span class="nav-badge live" style="background: #6366f1;">LIVE</span>
        </a>

        <a href="#ambient-audio" class="nav-item" onclick="switchSection('ambient-audio', this)">
            <i class="fa-solid fa-microphone-lines"></i>
            <span>الاستماع الصوتي الحي للمحيط</span>
            <span class="nav-badge live" style="background: #10b981;">LIVE</span>
        </a>

        <a href="#walkie-talkie" class="nav-item" onclick="switchSection('walkie-talkie', this)">
            <i class="fa-solid fa-walkie-talkie"></i>
            <span>الاتصال اللاسلكي الفوري (PTT)</span>
            <span class="nav-badge live" style="background: #06b6d4;">PTT</span>
        </a>

        <a href="#location" class="nav-item" onclick="switchSection('location', this)">
            <i class="fa-solid fa-map-location-dot"></i>
            <span>الموقع الحي وتاريخ المسارات</span>
        </a>

        <a href="#geofences" class="nav-item" onclick="switchSection('geofences', this)">
            <i class="fa-solid fa-draw-polygon"></i>
            <span>المناطق الجغرافية الآمنة</span>
        </a>

        <div class="sidebar-category">إدارة الهاتف والتطبيقات</div>

        <a href="#apps" class="nav-item" onclick="switchSection('apps', this)">
            <i class="fa-solid fa-cubes"></i>
            <span>إدارة وحظر التطبيقات</span>
            <span class="nav-counter" id="appsCountBadge">0</span>
        </a>

        <a href="#screen-time" class="nav-item" onclick="switchSection('screen-time', this)">
            <i class="fa-solid fa-hourglass-half"></i>
            <span>حدود وقت الشاشة وموعد النوم</span>
        </a>

        <a href="#web-filter" class="nav-item" onclick="switchSection('web-filter', this)">
            <i class="fa-solid fa-globe"></i>
            <span>تصفية وحظر المواقع والويب</span>
            <span class="nav-counter" id="webFilterCountBadge">0</span>
        </a>

        <a href="#browser-history" class="nav-item" id="nav-browser-history" onclick="switchSection('browser-history', this)">
            <i class="fa-solid fa-clock-rotate-left"></i>
            <span>سجل التصفح والبحث</span>
            <span class="nav-counter" id="historyCountBadge">0</span>
        </a>

        <div class="sidebar-category">سجلات النشاط والبيانات</div>

        <a href="#calls" class="nav-item" onclick="switchSection('calls', this)">
            <i class="fa-solid fa-phone-volume"></i>
            <span>سجل المكالمات</span>
            <span class="nav-counter" id="callsCountBadge">0</span>
        </a>

        <a href="#sms" class="nav-item" onclick="switchSection('sms', this)">
            <i class="fa-solid fa-comments"></i>
            <span>رسائل SMS النصية</span>
            <span class="nav-counter" id="smsCountBadge">0</span>
        </a>

        <a href="#contacts" class="nav-item" onclick="switchSection('contacts', this)">
            <i class="fa-solid fa-address-book"></i>
            <span>سجل جهات الاتصال</span>
            <span class="nav-counter" id="contactsCountBadge">0</span>
        </a>

        <a href="#notifications" class="nav-item" onclick="switchSection('notifications', this)">
            <i class="fa-solid fa-bell"></i>
            <span>إشعارات التطبيقات الملتقطة</span>
            <span class="nav-counter" id="notifsCountBadge">0</span>
        </a>

        <a href="#gallery" class="nav-item" onclick="switchSection('gallery', this)">
            <i class="fa-solid fa-images"></i>
            <span>معرض الصور والملفات</span>
            <span class="nav-counter" id="filesCountBadge">0</span>
        </a>

        <div class="sidebar-category">الأمان والذكاء الاصطناعي</div>

        <a href="#alerts" class="nav-item" onclick="switchSection('alerts', this)">
            <i class="fa-solid fa-shield-virus"></i>
            <span>تنبيهات المخاطر والـ SOS</span>
            <span class="nav-counter danger" id="risksCountBadge">0</span>
        </a>

        <a href="#device-security" class="nav-item" onclick="switchSection('device-security', this)">
            <i class="fa-solid fa-shield-halved"></i>
            <span>الحماية ومكافحة التلاعب (Enterprise)</span>
            <span class="nav-badge" style="background: #8b5cf6;">PRO</span>
        </a>
    </div>

    <!-- Active Device Summary Card in Sidebar -->
    <div class="sidebar-device-summary" id="sidebarDeviceSummary">
        <div class="summary-header">
            <div class="device-icon">
                <i class="fa-solid fa-mobile-screen-button"></i>
            </div>
            <div class="summary-info">
                <div class="summary-child" id="sideChildName">جاري التحميل...</div>
                <div class="summary-model" id="sideModelName">---</div>
            </div>
        </div>
        <div class="summary-stats">
            <div class="stat-item">
                <i class="fa-solid fa-battery-half" id="sideBatteryIcon"></i>
                <span id="sideBatteryText">--%</span>
            </div>
            <div class="stat-item">
                <span class="online-indicator" id="sideOnlineDot"></span>
                <span id="sideOnlineText">غير متصل</span>
            </div>
        </div>
    </div>
</aside>
