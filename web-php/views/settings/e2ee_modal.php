<?php
/**
 * Zero-Knowledge E2EE Passphrase Settings Modal
 */
declare(strict_types=1);
?>
<div class="modal-overlay" id="e2eeModal" style="display: none;">
    <div class="modal-box modal-md">
        <div class="modal-header">
            <div class="modal-title">
                <i class="fa-solid fa-key" style="color: var(--accent-emerald)"></i>
                <span>إعدادات التشفير التام والخصوصية (Zero-Knowledge E2EE)</span>
            </div>
            <button class="modal-close-btn" onclick="closeModal('e2eeModal')">✕</button>
        </div>
        <div class="modal-body">
            <p class="e2ee-explainer-text">
                باستخدام معيار <strong>Zero-Knowledge E2EE</strong>، يتم تشفير كافة المحادثات، المكالمات، ولقطات الشاشة محلياً على هاتف الطفل باستخدام مفتاح العائلة السري عبر خوارزمية <code>AES-256-GCM</code>. الخادم لا يمكنه قراءة أي محتوى إطلاقاً.
            </p>

            <div class="form-group" style="margin-top: 15px;">
                <label>مفتاح التشفير العائلي السري (Passphrase):</label>
                <div class="password-input-wrapper">
                    <input type="password" id="familyKeyInput" placeholder="أدخل مفتاح التشفير العائلي..." class="form-input">
                    <button class="toggle-pass-btn" type="button" onclick="togglePassVisibility('familyKeyInput')">
                        <i class="fa-solid fa-eye"></i>
                    </button>
                </div>
                <span class="input-hint">المفتاح الافتراضي مهيأ تلقائياً لمزامنة البيانات فك تشفيرها فوراً.</span>
            </div>

            <div class="modal-footer-simple" style="margin-top: 20px;">
                <button class="btn btn-secondary" onclick="closeModal('e2eeModal')">إلغاء</button>
                <button class="btn btn-emerald" onclick="saveFamilyKey()">
                    <i class="fa-solid fa-check"></i>
                    <span>حفظ وتطبيق التشفير</span>
                </button>
            </div>
        </div>
    </div>
</div>
