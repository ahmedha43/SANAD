<?php
/**
 * Subscription Status & Quota Banner
 * شريط حالة الاشتراك وحصة الأجهزة وقفل الميزات عند الانتهاء
 */
?>

<!-- Subscription Alert Banner (Shown if Expired or Suspended) -->
<div id="subscriptionAlertBanner" class="subscription-banner alert-expired" style="display: none;">
    <div class="sub-banner-content">
        <div class="sub-banner-icon">
            <i class="fa-solid fa-triangle-exclamation"></i>
        </div>
        <div class="sub-banner-text">
            <strong id="subBannerTitle">انتهت صلاحية اشتراكك!</strong>
            <span id="subBannerDesc">تم إيقاف ميزات البث والتحكم الفوري والأوامر مؤقتاً. يرجى تجديد الترخيص لمتابعة حماية أطفالك.</span>
        </div>
        <div class="sub-banner-actions">
            <button class="btn btn-warning btn-sm" onclick="UI.openModal('subscriptionModal')">
                <i class="fa-solid fa-arrows-rotate"></i> تجديد الاشتراك الآن
            </button>
        </div>
    </div>
</div>

<!-- Subscription Quota Pill (Always visible in Header/Top Bar) -->
<div id="subscriptionQuotaBar" class="sub-quota-bar" style="display: none;">
    <div class="quota-item">
        <span class="quota-label">الباقة الحالية:</span>
        <span class="quota-val badge-tier" id="quotaPlanName">--</span>
    </div>
    <div class="quota-item">
        <span class="quota-label">سعة الأجهزة:</span>
        <span class="quota-val" id="quotaDevicesUsed">-- / --</span>
    </div>
    <div class="quota-item">
        <span class="quota-label">الصلاحية:</span>
        <span class="quota-val" id="quotaExpiryDate">--</span>
    </div>
</div>

<!-- Modal: Subscription Details & Renewal Paywall -->
<div class="modal-overlay" id="subscriptionModal" style="display: none;">
    <div class="modal-dialog modal-md">
        <div class="modal-header">
            <h3><i class="fa-solid fa-id-card text-brand"></i> تفاصيل الاشتراك والباقة</h3>
            <button class="modal-close-btn" onclick="UI.closeModal('subscriptionModal')">&times;</button>
        </div>
        <div class="modal-body text-center">
            <div id="subModalIcon" class="sub-modal-badge mb-3">
                <i class="fa-solid fa-shield-halved fa-3x text-warning"></i>
            </div>
            <h4 id="subModalTitle" class="fw-bold mb-1">تفاصيل ترخيص العائلة</h4>
            <p id="subModalStatusMsg" class="text-muted mb-4">بيانات باقتك الحالية وسعة الأجهزة المتاحة</p>

            <div class="sub-details-box p-3 mb-4 rounded" style="background: rgba(255,255,255,0.04); border: 1px solid rgba(255,255,255,0.1); text-align: right;">
                <div class="d-flex justify-content-between py-2 border-bottom border-secondary">
                    <span class="text-muted">اسم الباقة:</span>
                    <strong id="subModalPlan">--</strong>
                </div>
                <div class="d-flex justify-content-between py-2 border-bottom border-secondary">
                    <span class="text-muted">حالة الترخيص:</span>
                    <span id="subModalStatusBadge" class="badge">--</span>
                </div>
                <div class="d-flex justify-content-between py-2 border-bottom border-secondary">
                    <span class="text-muted">الأجهزة المستخدمة:</span>
                    <strong id="subModalDevices">-- / --</strong>
                </div>
                <div class="d-flex justify-content-between py-2">
                    <span class="text-muted">تاريخ الانتهاء:</span>
                    <strong id="subModalExpiry">--</strong>
                </div>
            </div>

            <div class="alert alert-info py-2 small" style="background: rgba(59, 130, 246, 0.1); border: 1px solid rgba(59, 130, 246, 0.2); color: #93c5fd;">
                <i class="fa-solid fa-circle-info me-1"></i>
                لتجديد الاشتراك أو ترقية الباقة لزيادة عدد الأجهزة، يرجى التواصل مع إدارة المنصة أو مسؤول النظام.
            </div>
        </div>
        <div class="modal-footer">
            <button type="button" class="btn btn-secondary w-100" onclick="UI.closeModal('subscriptionModal')">إغلاق</button>
        </div>
    </div>
</div>

<!-- Modal: Feature Locked Paywall -->
<div class="modal-overlay" id="featureLockedModal" style="display: none;">
    <div class="modal-dialog modal-md">
        <div class="modal-header">
            <h3><i class="fa-solid fa-lock text-warning"></i> ميزة غير متوفرة في باقتك</h3>
            <button class="modal-close-btn" onclick="UI.closeModal('featureLockedModal')">&times;</button>
        </div>
        <div class="modal-body text-center">
            <div class="sub-modal-badge mb-3">
                <i class="fa-solid fa-crown fa-3x" style="color: #f59e0b;"></i>
            </div>
            <h4 id="lockedFeatureTitle" class="fw-bold mb-2">ميزة مدفوعة (Premium VIP)</h4>
            <p id="lockedFeatureDesc" class="text-muted mb-4">
                هذه الميزة غير مشمولة في باقتك الحالية (<span id="lockedCurrentPlanName" class="text-info fw-bold">الباقة المجانية</span>).
                يرجى الترقية إلى باقة متقدمة للوصول الكامل إليها.
            </p>

            <div class="alert alert-warning py-3 text-start small mb-4" style="background: rgba(245, 158, 11, 0.1); border: 1px solid rgba(245, 158, 11, 0.3); color: #fde68a;">
                <div class="fw-bold mb-1"><i class="fa-solid fa-sparkles me-1"></i> باقات تدعم هذه الميزة:</div>
                <ul class="mb-0 ps-3">
                    <li><strong>الباقة المتقدمة (Premium)</strong>: لقطات شاشة، ذكاء اصطناعي، وسياج جغرافي.</li>
                    <li><strong>باقة العائلة غير المحدودة (Unlimited VIP)</strong>: بث مباشر للكاميرا والصوت WebRTC وكافة الميزات بلا قيود.</li>
                </ul>
            </div>
        </div>
        <div class="modal-footer">
            <button type="button" class="btn btn-warning w-100 mb-2" onclick="UI.closeModal('featureLockedModal'); UI.openModal('subscriptionModal');">
                <i class="fa-solid fa-arrow-up-right-from-square"></i> تفاصيل الترقية والاشتراك
            </button>
            <button type="button" class="btn btn-secondary w-100" onclick="UI.closeModal('featureLockedModal')">إلغاء</button>
        </div>
    </div>
</div>

<style>
.subscription-banner {
    padding: 12px 20px;
    margin-bottom: 20px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    animation: fadeInDown 0.3s ease;
}
.subscription-banner.alert-expired {
    background: linear-gradient(135deg, rgba(239, 68, 68, 0.2), rgba(185, 28, 28, 0.3));
    border: 1px solid rgba(239, 68, 68, 0.5);
    color: #fca5a5;
}
.sub-banner-content {
    display: flex;
    align-items: center;
    width: 100%;
    gap: 15px;
    flex-wrap: wrap;
}
.sub-banner-icon {
    font-size: 24px;
    color: #ef4444;
}
.sub-banner-text {
    flex: 1;
    display: flex;
    flex-direction: column;
}
.sub-banner-text strong {
    font-size: 15px;
    color: #fee2e2;
}
.sub-banner-text span {
    font-size: 13px;
    color: #fca5a5;
}
.sub-quota-bar {
    display: flex;
    gap: 20px;
    background: rgba(30, 41, 59, 0.6);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 10px;
    padding: 8px 16px;
    margin-bottom: 16px;
    font-size: 13px;
    flex-wrap: wrap;
}
.quota-item {
    display: flex;
    align-items: center;
    gap: 8px;
}
.quota-label {
    color: var(--text-muted, #94a3b8);
}
.quota-val {
    font-weight: 700;
    color: #f1f5f9;
}
.badge-tier {
    background: rgba(59, 130, 246, 0.2);
    color: #60a5fa;
    padding: 2px 8px;
    border-radius: 6px;
    border: 1px solid rgba(59, 130, 246, 0.4);
}
</style>
