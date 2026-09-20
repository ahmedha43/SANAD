<?php
/**
 * Authentication Modal Component (Login & Register)
 */
declare(strict_types=1);
?>
<div class="modal-overlay" id="authModal" style="display: none;">
    <div class="modal-box modal-auth">
        <div class="modal-header auth-header">
            <div class="auth-brand-icon">
                <i class="fa-solid fa-shield-halved"></i>
            </div>
            <h3 class="auth-title" id="authModalTitle">تسجيل الدخول - منظومة سَنَد</h3>
            <p class="auth-subtitle" id="authModalSubtitle">الوصول الكامل إلى منظومة سَنَد لحماية ورعاية أجهزة العائلة</p>
        </div>

        <div class="modal-body auth-body">
            <!-- Alert message for errors -->
            <div class="auth-alert" id="authAlertBox" style="display: none;"></div>

            <!-- Full Name (Register Mode Only) -->
            <div class="form-group" id="registerNameGroup" style="display: none;">
                <label>الاسم الكامل لولي الأمر:</label>
                <div class="input-with-icon">
                    <i class="fa-solid fa-user"></i>
                    <input type="text" id="registerName" placeholder="مثال: أحمد علي" class="form-input">
                </div>
            </div>

            <!-- Email -->
            <div class="form-group">
                <label>البريد الإلكتروني:</label>
                <div class="input-with-icon">
                    <i class="fa-solid fa-envelope"></i>
                    <input type="email" id="authEmail" value="admin@parentalcontrol.local" placeholder="parent@example.com" class="form-input" onkeyup="if(event.key==='Enter') handleAuthSubmit(event)" required>
                </div>
            </div>

            <!-- Password -->
            <div class="form-group">
                <label>كلمة المرور:</label>
                <div class="input-with-icon">
                    <i class="fa-solid fa-lock"></i>
                    <input type="password" id="authPassword" value="Admin@123456" placeholder="••••••••" class="form-input" onkeyup="if(event.key==='Enter') handleAuthSubmit(event)" required>
                    <button type="button" class="toggle-pass-btn-inline" onclick="togglePassVisibility('authPassword')">
                        <i class="fa-solid fa-eye"></i>
                    </button>
                </div>
            </div>

            <!-- Quick Demo Credential Hint -->
            <div class="auth-demo-hint" id="authDemoHint">
                <i class="fa-solid fa-wand-magic-sparkles"></i>
                <span>تم ملء الحساب الافتراضي للنظام مسبقاً للتجربة الفورية.</span>
            </div>

            <!-- Submit Button -->
            <button class="btn btn-primary btn-block btn-lg" id="authSubmitBtn" onclick="handleAuthSubmit(event)">
                <span id="authSubmitText">تسجيل الدخول</span>
                <i class="fa-solid fa-arrow-left"></i>
            </button>

            <!-- Toggle between Login & Register -->
            <div class="auth-toggle-row">
                <span id="authToggleQuestion">ليس لديك حساب؟</span>
                <a href="javascript:void(0)" id="authToggleLink" onclick="toggleAuthMode()" class="auth-link">
                    إنشاء حساب ولي أمر جديد
                </a>
            </div>
        </div>
    </div>
</div>
