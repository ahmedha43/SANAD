<?php
/**
 * Global Top Navbar Component
 */
declare(strict_types=1);
?>
<header class="top-navbar">
    <div class="navbar-left">
        <button class="mobile-toggle-btn" id="mobileMenuBtn" onclick="toggleSidebar()">
            <i class="fa-solid fa-bars"></i>
        </button>
        <div class="navbar-brand">
            <div class="brand-icon">
                <i class="fa-solid fa-shield-halved"></i>
            </div>
            <div class="brand-text">
                <span class="brand-title">سَنَد | SANAD</span>
                <span class="brand-badge">PRO CLOUD</span>
            </div>
        </div>
    </div>

    <div class="navbar-right">
        <!-- Live Connection Status Badge -->
        <div class="connection-status" id="globalWsStatus" onclick="reconnectWebSocket()" style="cursor: pointer;" title="انقر لإعادة الاتصال الفوري بالسيرفر">
            <span class="status-pulse-dot offline" id="wsPulseDot"></span>
            <span class="status-text" id="wsStatusText">جاري الاتصال...</span>
        </div>

        <!-- Zero-Knowledge E2EE Key Status -->
        <button class="nav-pill-btn e2ee-btn" onclick="openModal('e2eeModal')" title="إعدادات مفتاح التشفير">
            <i class="fa-solid fa-key"></i>
            <span>تشفير E2EE: <b id="e2eeStatusLabel" style="color:var(--accent-emerald)">مفعّل</b></span>
        </button>

        <!-- Refresh Active Child Data Button -->
        <button class="nav-icon-btn" onclick="refreshActiveDeviceData()" title="تحديث البيانات">
            <i class="fa-solid fa-arrows-rotate" id="refreshSpinIcon"></i>
        </button>

        <!-- User Profile & Logout -->
        <div class="user-menu">
            <div class="user-avatar" id="navUserAvatar">
                <i class="fa-solid fa-user"></i>
            </div>
            <div class="user-info">
                <span class="user-name" id="navUserName">ولي الأمر</span>
                <span class="user-role">حساب سَنَد المعتمد</span>
            </div>
            <button class="logout-btn" onclick="logout()" title="تسجيل الخروج">
                <i class="fa-solid fa-right-from-bracket"></i>
            </button>
        </div>
    </div>
</header>
