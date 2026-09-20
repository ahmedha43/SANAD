<?php
/**
 * Emergency Alert Banner Component (SOS / AI Risk)
 */
declare(strict_types=1);
?>
<div class="emergency-banner" id="riskBanner" style="display: none;">
    <div class="banner-content">
        <div class="banner-icon-pulse">
            <i class="fa-solid fa-triangle-exclamation"></i>
        </div>
        <div class="banner-text">
            <div class="banner-title" id="riskBannerTitle">إنذار أمني ذكي طارئ!</div>
            <div class="banner-desc" id="riskBannerDesc">اكتشف محرك الذكاء الاصطناعي محتوى عالي الخطورة على جهاز الطفل.</div>
        </div>
    </div>
    <div class="banner-actions">
        <button class="btn btn-warning-sm" onclick="switchSection('alerts')">عرض تفاصيل الخطر</button>
        <button class="btn btn-dismiss-sm" onclick="dismissRiskBanner()">تم الاطلاع</button>
    </div>
</div>
