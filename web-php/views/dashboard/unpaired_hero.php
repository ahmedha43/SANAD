<?php
declare(strict_types=1);
/**
 * SANAD Platform - Permanent Auto-Renewing Pairing Hero for Unpaired Children
 * كارت الاقتران الدائم والمتجدد للأجهزة غير المقترنة
 */
?>
<div id="overviewUnpairedHero" class="unpaired-hero-card" style="display: none;">
    <div class="unpaired-hero-glow"></div>
    <div class="unpaired-hero-content">
        <div class="unpaired-hero-header">
            <div class="unpaired-badge-live">
                <span class="pulse-dot"></span>
                <span>بانتظار إقران الجهاز</span>
            </div>
            <h2 class="unpaired-title">
                ربط جهاز الطفل: <span id="unpairedChildName" class="highlight-cyan">جاري التحميل...</span>
            </h2>
            <p class="unpaired-desc">
                رمز الاقتران أدناه نشط <strong>بشكل دائم ومتجدد تلقائياً</strong>. افتح تطبيق سَنَد على هاتف أو كمبيوتر طفلك واكتب هذا الرمز لربطه فوراً وبدء الحماية والتتبع:
            </p>
        </div>

        <div class="unpaired-hero-body">
            <!-- Left: Digits & Actions -->
            <div class="unpaired-digits-col">
                <div class="unpaired-digits-wrapper" id="unpairedDigitsWrapper">
                    <span class="unpaired-digit-box">-</span>
                    <span class="unpaired-digit-box">-</span>
                    <span class="unpaired-digit-box">-</span>
                    <span class="unpaired-digit-box">-</span>
                    <span class="unpaired-digit-box">-</span>
                    <span class="unpaired-digit-box">-</span>
                </div>

                <div class="unpaired-meta-row">
                    <div class="unpaired-timer-pill">
                        <i class="fa-solid fa-arrows-rotate fa-spin-hover"></i>
                        <span>يتجدد تلقائياً بعد:</span>
                        <strong id="unpairedHeroCountdown">15:00</strong>
                    </div>

                    <button class="btn btn-sm btn-cyan" onclick="copyActiveUnpairedCode()" title="نسخ الرمز">
                        <i class="fa-regular fa-copy"></i>
                        <span>نسخ الرمز</span>
                    </button>

                    <button class="btn btn-sm btn-outline-cyan" onclick="renewActiveUnpairedCode()" title="توليد كود جديد فوراً">
                        <i class="fa-solid fa-rotate" id="unpairedRenewIcon"></i>
                        <span>تجديد الآن</span>
                    </button>
                </div>

                <div class="unpaired-steps-row">
                    <div class="unpaired-step-item">
                        <div class="step-num">1</div>
                        <div class="step-text">افتح تطبيق سَنَد على جهاز طفلك</div>
                    </div>
                    <div class="unpaired-step-arrow"><i class="fa-solid fa-arrow-left"></i></div>
                    <div class="unpaired-step-item">
                        <div class="step-num">2</div>
                        <div class="step-text">اكتب الرمز المكون من 6 أرقام</div>
                    </div>
                    <div class="unpaired-step-arrow"><i class="fa-solid fa-arrow-left"></i></div>
                    <div class="unpaired-step-item">
                        <div class="step-num">3</div>
                        <div class="step-text">يتم الاقتران ويبدأ التتبع فوراً</div>
                    </div>
                </div>
            </div>

            <!-- Right: QR Code for rapid pairing -->
            <div class="unpaired-qr-col">
                <div class="unpaired-qr-card">
                    <div class="qr-container-box" id="unpairedHeroQrCode"></div>
                    <span class="qr-caption"><i class="fa-solid fa-qrcode"></i> أو امسح الرمز عبر الكاميرا</span>
                </div>
            </div>
        </div>
    </div>
</div>
