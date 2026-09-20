<?php
/**
 * Instant Silent Screenshot Preview Modal Component
 */
declare(strict_types=1);
?>
<div class="modal-overlay" id="screenshotModal" style="display: none;">
    <div class="modal-box modal-md">
        <div class="modal-header">
            <div class="modal-title">
                <i class="fa-solid fa-camera" style="color: var(--accent-cyan)"></i>
                <span>لقطة شاشة صامتة وفورية (Live Screenshot)</span>
            </div>
            <button class="modal-close-btn" onclick="closeModal('screenshotModal')">✕</button>
        </div>
        <div class="modal-body modal-media-body">
            <div id="screenshotLoading" class="text-center text-muted" style="padding: 40px;">
                <i class="fa-solid fa-spinner fa-spin" style="font-size: 2rem; color: var(--accent-cyan); margin-bottom: 15px;"></i>
                <div style="font-size: 1rem; color: var(--text-main);">جاري التقاط لقطة الشاشة في جهاز الطفل ونقلها مشفرة...</div>
                <div style="font-size: 0.8rem; color: var(--text-muted); margin-top: 8px;">يُرجى إبقاء النافذة مفتوحة لحين اكتمال النقل</div>
            </div>
            <div id="screenshotError" style="display: none; padding: 25px; text-align: center; background: rgba(239, 68, 68, 0.08); border: 1px solid rgba(239, 68, 68, 0.2); border-radius: 12px; margin: 15px;">
                <i class="fa-solid fa-circle-exclamation" style="font-size: 2.2rem; color: #ef4444; margin-bottom: 12px; display: block;"></i>
                <div id="screenshotErrorText" style="font-size: 1rem; font-weight: 600; color: #f87171; margin-bottom: 8px;"></div>
                <div style="font-size: 0.82rem; color: var(--text-muted); line-height: 1.5;">
                    💡 نصائح للحل: تأكد من تشغيل شاشة جهاز الطفل، اتصاله بالإنترنت، وتفعيل خيار (Accessibility Service) لتطبيق Kids Agent في إعدادات الجهاز.
                </div>
            </div>
            <img id="screenshotModalImage" src="" alt="Live Screenshot" class="modal-preview-img" style="display: none; max-width: 100%; max-height: 70vh; border-radius: 8px; margin: 0 auto; box-shadow: 0 4px 20px rgba(0,0,0,0.5);">
        </div>
        <div class="modal-footer-bar">
            <span class="media-meta-text" id="screenshotCaptureTime">الوقت: الآن</span>
            <div class="footer-buttons">
                <button class="btn btn-outline-sm" onclick="requestScreenshot()">
                    <i class="fa-solid fa-rotate"></i>
                    <span>إعادة المحاولة</span>
                </button>
                <a id="screenshotDownloadBtn" href="#" download="screenshot.jpg" class="btn btn-primary-sm" style="display: none;">
                    <i class="fa-solid fa-download"></i>
                    <span>حفظ الصورة</span>
                </a>
            </div>
        </div>
    </div>
</div>
