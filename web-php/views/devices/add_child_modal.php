<?php
/**
 * Add Child & Device Pairing Modal Component
 */
declare(strict_types=1);
?>
<div class="modal-overlay" id="addChildModal" style="display: none;">
    <div class="modal-box modal-md">
        <div class="modal-header">
            <div class="modal-title">
                <i class="fa-solid fa-child-reaching" style="color: var(--accent-cyan)"></i>
                <span>إضافة طفل وربط جهاز جديد</span>
            </div>
            <button class="modal-close-btn" onclick="closeModal('addChildModal')">✕</button>
        </div>

        <div class="modal-body">
            <!-- Step 1: Create Child Form -->
            <div id="addChildStep1">
                <div class="form-group">
                    <label>اسم الطفل:</label>
                    <input type="text" id="newChildName" placeholder="مثال: يوسف، سارة..." class="form-input" required>
                </div>
                <div class="form-group">
                    <label>عمر الطفل (اختياري):</label>
                    <input type="number" id="newChildAge" placeholder="12" min="3" max="18" class="form-input">
                </div>
                <div class="info-note">
                    <i class="fa-solid fa-circle-info"></i>
                    <span>بعد إضافة اسم الطفل، سيتم توليد رمز اقتران سداسي (6 أرقام) ورمز QR لمسحه بجهاز الطفل.</span>
                </div>
                <button class="btn btn-primary btn-block" id="btnCreateChild" onclick="submitCreateChild()">
                    <span>إنشاء وتوليد كود الاقتران</span>
                    <i class="fa-solid fa-arrow-left"></i>
                </button>
            </div>

            <!-- Step 2: Display Pairing Code & QR -->
            <div id="addChildStep2" style="display: none;">
                <div class="pairing-container">
                    <div class="pairing-header-text">
                        افتح تطبيق <b>Kids Agent</b> على جهاز الطفل وامسح الرمز أو أدخل الكود:
                    </div>

                    <!-- 6-digit Pairing Code Display -->
                    <div class="code-box-wrapper">
                        <div class="digits-row" id="pairCodeDigits">
                            <span class="code-digit">-</span>
                            <span class="code-digit">-</span>
                            <span class="code-digit">-</span>
                            <span class="code-digit">-</span>
                            <span class="code-digit">-</span>
                            <span class="code-digit">-</span>
                        </div>
                        <button class="copy-code-btn" onclick="copyPairCode()" title="نسخ الكود">
                            <i class="fa-solid fa-copy"></i>
                        </button>
                    </div>

                    <!-- Countdown Timer -->
                    <div class="timer-badge">
                        <i class="fa-solid fa-stopwatch"></i>
                        <span>صلاحية الكود: <b id="pairCodeTimer">15:00</b> دقيقة</span>
                    </div>

                    <!-- QR Code Canvas Container -->
                    <div class="qr-canvas-wrapper">
                        <div id="pairQrCodeContainer"></div>
                    </div>

                    <!-- WebUSB Fast Provisioning Card -->
                    <div class="webusb-fast-card" style="margin: 15px 0; padding: 14px; background: rgba(6, 182, 212, 0.08); border: 1px solid rgba(6, 182, 212, 0.3); border-radius: 12px; text-align: center;">
                        <div style="font-weight: 700; color: #fff; font-size: 0.95rem; margin-bottom: 6px; display: flex; align-items: center; justify-content: center; gap: 8px;">
                            <i class="fa-solid fa-bolt" style="color: var(--accent-cyan);"></i>
                            <span>تفعيل وربط فوري بنقرة واحدة عبر USB</span>
                            <span style="font-size: 0.72rem; background: rgba(16, 185, 129, 0.2); color: #10b981; padding: 2px 6px; border-radius: 4px;">أسرع طريقة</span>
                        </div>
                        <p style="font-size: 0.8rem; color: var(--text-muted); line-height: 1.5; margin-bottom: 12px;">
                            صل هاتف الطفل بالكمبيوتر واضغط الزر ليقوم المتصفح تلقائياً بحقن رمز الاقتران ومنح كافة الصلاحيات وتفعيل الحماية القصوى بنقرة واحدة!
                        </p>
                        <button type="button" class="btn btn-primary btn-block" onclick="startWebUsbPairingFromModal()" style="background: linear-gradient(135deg, #06b6d4, #3b82f6); border: none; font-weight: 700; padding: 10px 16px;">
                            <i class="fa-solid fa-wand-magic-sparkles"></i>
                            <span>توصيل وتفعيل الجهاز بكود الاقتران الآن</span>
                        </button>
                    </div>

                    <div class="pairing-status-indicator" id="pairingWaitStatus">
                        <i class="fa-solid fa-spinner fa-spin"></i>
                        <span>بانتظار مسح الكود من جهاز الطفل...</span>
                    </div>

                    <button class="btn btn-outline btn-block" onclick="finishPairingWorkflow()">
                        <span>تم الربط بنجاح / إغلاق</span>
                    </button>
                </div>
            </div>
        </div>
    </div>
</div>

<script>
function startWebUsbPairingFromModal() {
    const code = window._currentGeneratedPairCode || null;
    closeModal('addChildModal');
    if (typeof openDeviceOwnerModal === 'function') {
        openDeviceOwnerModal();
        setTimeout(() => {
            if (typeof startWebUsbProvisioning === 'function') {
                startWebUsbProvisioning(code);
            }
        }, 300);
    }
}
</script>
