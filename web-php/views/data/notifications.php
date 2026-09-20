<?php
/**
 * Intercepted Notifications Stream Component
 */
declare(strict_types=1);
?>
<section class="panel-card" id="notificationsSection">
    <div class="panel-card-header">
        <div class="panel-title-group">
            <i class="fa-solid fa-bell" style="color: var(--accent-rose)"></i>
            <div>
                <h3>إشعارات التطبيقات الملتقطة فورياً (Intercepted Notifications)</h3>
                <span class="sub-text">سجل الرسائل والتنبيهات الواردة على هاتف الطفل من كافة التطبيقات فور وصولها</span>
            </div>
        </div>
        <button class="btn btn-outline-sm" onclick="App.loadNotifications()">
            <i class="fa-solid fa-arrows-rotate"></i>
            <span>تحديث</span>
        </button>
    </div>

    <div class="notifications-stream" id="notificationsStreamContainer">
        <div class="text-center text-muted" style="padding: 30px;">جاري تحميل سجل الإشعارات...</div>
    </div>
</section>
