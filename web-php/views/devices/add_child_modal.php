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
