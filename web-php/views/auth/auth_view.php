<?php
/**
 * Professional Full-Screen Authentication View
 * واجهة تسجيل الدخول وإنشاء الحساب الاحترافية المستقلة
 */
declare(strict_types=1);
?>
<!-- FULLSCREEN AUTHENTICATION SCREEN -->
<div id="authScreen" class="auth-page-wrapper" style="display: none;">
    <!-- Ambient Cyber Glows -->
    <div class="auth-ambient-glow glow-1"></div>
    <div class="auth-ambient-glow glow-2"></div>
    <div class="auth-ambient-glow glow-3"></div>
    <div class="auth-cyber-grid"></div>

    <div class="auth-main-card">
        <!-- BRAND & FEATURES SHOWCASE PANEL -->
        <div class="auth-showcase-panel">
            <div class="showcase-top-badge">
                <span class="pulse-indicator"></span>
                <span>منظومة سَنَد للأمان والرعاية الأسرية • إصدار 2026 PRO</span>
            </div>

            <div class="showcase-hero">
                <div class="showcase-logo-group">
                    <div class="showcase-logo-icon">
                        <i class="fa-solid fa-shield-halved"></i>
                    </div>
                    <div class="showcase-logo-text">
                        <h1>سَنَد | SANAD</h1>
                        <span>Next-Gen Family Care & Safety Platform</span>
                    </div>
                </div>

                <p class="showcase-desc">
                    منصة سحابية متكاملة لمتابعة أمان أطفالك، بث الشاشة والكاميرا في الوقت الفعلي، وتوفير بيئة رقمية آمنة بتقنيات الذكاء الاصطناعي والتشفير التام.
                </p>
            </div>

            <!-- Features Highlights List -->
            <div class="showcase-features">
                <div class="showcase-feat-item">
                    <div class="feat-icon feat-cyan">
                        <i class="fa-solid fa-desktop"></i>
                    </div>
                    <div class="feat-body">
                        <h4>بث الشاشة الحية (30fps WebRTC)</h4>
                        <p>عرض شاشة الطفل بدقة فائقة وبث فوري بدون تأخير أو لقطات دورية صامتة.</p>
                    </div>
                </div>

                <div class="showcase-feat-item">
                    <div class="feat-icon feat-blue">
                        <i class="fa-solid fa-map-location-dot"></i>
                    </div>
                    <div class="feat-body">
                        <h4>تتبع GPS المباشر والمناطق الجغرافية</h4>
                        <p>تحديد الدوائر الآمنة وتنبيهات فورية عند دخول أو خروج الطفل من المنطقة.</p>
                    </div>
                </div>

                <div class="showcase-feat-item">
                    <div class="feat-icon feat-purple">
                        <i class="fa-solid fa-video"></i>
                    </div>
                    <div class="feat-body">
                        <h4>الكاميرا عن بُعد والصوت المحيط</h4>
                        <p>فتح الكاميرا الأمامية أو الخلفية في الوقت الفعلي والاستماع الآمن.</p>
                    </div>
                </div>

                <div class="showcase-feat-item">
                    <div class="feat-icon feat-emerald">
                        <i class="fa-solid fa-lock"></i>
                    </div>
                    <div class="feat-body">
                        <h4>تشفير كامل للخصوصية (E2EE)</h4>
                        <p>جميع الصور، المكالمات، والمواقع مشفرة ولا يمكن لأي طرف ثالث فكها.</p>
                    </div>
                </div>
            </div>

            <!-- Trust / Security Pill Badges -->
            <div class="showcase-trust-bar">
                <div class="trust-tag"><i class="fa-solid fa-server"></i> خوادم سحابية نشطة 100%</div>
                <div class="trust-tag"><i class="fa-solid fa-shield-check"></i> تشفير E2EE 256-bit</div>
                <div class="trust-tag"><i class="fa-solid fa-bolt"></i> استجابة فورية أقل من 200ms</div>
            </div>
        </div>

        <!-- FORM INTERACTION PANEL -->
        <div class="auth-form-panel">
            <div class="auth-form-card">
                
                <!-- Mobile Brand Bar -->
                <div class="auth-compact-brand">
                    <div class="compact-logo">
                        <i class="fa-solid fa-shield-halved"></i>
                    </div>
                    <div>
                        <h2>سَنَد | SANAD</h2>
                        <small>منظومة الرعاية والحماية الأسرية</small>
                    </div>
                </div>

                <!-- Navigation Tabs (Login / Register) -->
                <div class="auth-nav-tabs">
                    <button type="button" class="auth-nav-tab active" id="tabBtnLogin" onclick="switchAuthTab('login')">
                        <i class="fa-solid fa-arrow-right-to-bracket"></i>
                        <span>تسجيل الدخول</span>
                    </button>
                    <button type="button" class="auth-nav-tab" id="tabBtnRegister" onclick="switchAuthTab('register')">
                        <i class="fa-solid fa-user-plus"></i>
                        <span>إنشاء حساب ولي أمر</span>
                    </button>
                </div>

                <!-- Dynamic Alert Banner for Errors & Success -->
                <div id="authAlertBanner" class="auth-alert-banner" style="display: none;">
                    <div class="alert-icon-wrap" id="authAlertIconWrap">
                        <i class="fa-solid fa-circle-exclamation" id="authAlertIcon"></i>
                    </div>
                    <div class="alert-msg-wrap" id="authAlertText"></div>
                </div>

                <!-- 1. LOGIN FORM -->
                <form id="loginForm" class="auth-form-section" onsubmit="submitLogin(event)">
                    <div class="auth-form-intro">
                        <h3>أهلاً بك مجدداً 👋</h3>
                        <p>سجّل دخولك للوصول إلى أجهزة أطفالك والاطمئنان عليهم مباشرة</p>
                    </div>

                    <div class="auth-field-group">
                        <label for="loginEmail">البريد الإلكتروني</label>
                        <div class="auth-input-container">
                            <i class="fa-solid fa-envelope field-icon"></i>
                            <input type="email" id="loginEmail" class="auth-text-input" value="admin@parentalcontrol.local" placeholder="parent@example.com" required autocomplete="username">
                        </div>
                    </div>

                    <div class="auth-field-group">
                        <div class="field-label-split">
                            <label for="loginPassword">كلمة المرور</label>
                            <a href="javascript:void(0)" onclick="forgotPasswordHint()" class="field-link">نسيت كلمة المرور؟</a>
                        </div>
                        <div class="auth-input-container">
                            <i class="fa-solid fa-lock field-icon"></i>
                            <input type="password" id="loginPassword" class="auth-text-input" value="Admin@123456" placeholder="••••••••" required autocomplete="current-password">
                            <button type="button" class="auth-eye-btn" onclick="togglePasswordVisibility('loginPassword', this)">
                                <i class="fa-solid fa-eye"></i>
                            </button>
                        </div>
                    </div>

                    <div class="auth-options-row">
                        <label class="auth-checkbox">
                            <input type="checkbox" id="rememberMe" checked>
                            <span class="checkbox-mark"></span>
                            <span>تذكر تسجيل دخولي في هذا المتصفح</span>
                        </label>
                    </div>

                    <!-- Quick Demo Credentials Shortcut -->
                    <div class="auth-demo-shortcut" onclick="fillAndLoginDemo()">
                        <div class="shortcut-badge">
                            <i class="fa-solid fa-bolt"></i>
                        </div>
                        <div class="shortcut-info">
                            <strong>دخول سريع بالحساب التجريبي المعتمد</strong>
                            <span>admin@parentalcontrol.local (نقرة واحدة للتجربة الفورية)</span>
                        </div>
                        <i class="fa-solid fa-arrow-left shortcut-arrow"></i>
                    </div>

                    <!-- Main Submit Button -->
                    <button type="submit" class="auth-action-btn btn-login-theme" id="btnLoginSubmit">
                        <span class="btn-text">تسجيل الدخول إلى اللوحة</span>
                        <i class="fa-solid fa-arrow-left btn-arrow"></i>
                        <span class="btn-loader" style="display: none;"><i class="fa-solid fa-circle-notch fa-spin"></i></span>
                    </button>
                </form>

                <!-- 2. REGISTER FORM -->
                <form id="registerForm" class="auth-form-section" style="display: none;" onsubmit="submitRegister(event)">
                    <div class="auth-form-intro">
                        <h3>إنشاء حساب ولي أمر جديد 🛡️</h3>
                        <p>ابدأ برعاية أجهزة أطفالك وتأمين سلامتهم في دقائق معدودة</p>
                    </div>

                    <div class="auth-field-group">
                        <label for="regFullName">الاسم الكامل لولي الأمر</label>
                        <div class="auth-input-container">
                            <i class="fa-solid fa-user field-icon"></i>
                            <input type="text" id="regFullName" class="auth-text-input" placeholder="مثال: أحمد محمد علي" required>
                        </div>
                    </div>

                    <div class="auth-field-group">
                        <label for="regEmail">البريد الإلكتروني</label>
                        <div class="auth-input-container">
                            <i class="fa-solid fa-envelope field-icon"></i>
                            <input type="email" id="regEmail" class="auth-text-input" placeholder="parent@example.com" required autocomplete="email">
                        </div>
                    </div>

                    <div class="auth-dual-grid">
                        <div class="auth-field-group">
                            <label for="regFamilyName">اسم الأسرة / العائلة (اختياري)</label>
                            <div class="auth-input-container">
                                <i class="fa-solid fa-people-roof field-icon"></i>
                                <input type="text" id="regFamilyName" class="auth-text-input" placeholder="عائلة أحمد">
                            </div>
                        </div>
                        <div class="auth-field-group">
                            <label for="regPhone">رقم الهاتف (اختياري)</label>
                            <div class="auth-input-container">
                                <i class="fa-solid fa-phone field-icon"></i>
                                <input type="tel" id="regPhone" class="auth-text-input" placeholder="05XXXXXXXX">
                            </div>
                        </div>
                    </div>

                    <div class="auth-field-group">
                        <label for="regPassword">كلمة المرور</label>
                        <div class="auth-input-container">
                            <i class="fa-solid fa-lock field-icon"></i>
                            <input type="password" id="regPassword" class="auth-text-input" placeholder="8 خانات على الأقل" required onkeyup="checkPasswordStrength(this.value)">
                            <button type="button" class="auth-eye-btn" onclick="togglePasswordVisibility('regPassword', this)">
                                <i class="fa-solid fa-eye"></i>
                            </button>
                        </div>
                        <!-- Strength meter -->
                        <div class="auth-strength-meter">
                            <div class="meter-bar" id="regStrengthBar"></div>
                        </div>
                    </div>

                    <div class="auth-field-group">
                        <label for="regPasswordConfirm">تأكيد كلمة المرور</label>
                        <div class="auth-input-container">
                            <i class="fa-solid fa-shield-check field-icon"></i>
                            <input type="password" id="regPasswordConfirm" class="auth-text-input" placeholder="أعد إدخال كلمة المرور" required>
                            <button type="button" class="auth-eye-btn" onclick="togglePasswordVisibility('regPasswordConfirm', this)">
                                <i class="fa-solid fa-eye"></i>
                            </button>
                        </div>
                    </div>

                    <div class="auth-options-row">
                        <label class="auth-checkbox">
                            <input type="checkbox" id="agreeTerms" required checked>
                            <span class="checkbox-mark"></span>
                            <span>أوافق على <a href="javascript:void(0)">شروط الخدمة</a> وسياسة <a href="javascript:void(0)">حماية خصوصية الأطفال</a></span>
                        </label>
                    </div>

                    <!-- Main Register Button -->
                    <button type="submit" class="auth-action-btn btn-register-theme" id="btnRegisterSubmit">
                        <span class="btn-text">إنشاء الحساب والبدء الآن</span>
                        <i class="fa-solid fa-arrow-left btn-arrow"></i>
                        <span class="btn-loader" style="display: none;"><i class="fa-solid fa-circle-notch fa-spin"></i></span>
                    </button>
                </form>

                <!-- Card Footer Security Note -->
                <div class="auth-card-footnote">
                    <i class="fa-solid fa-lock"></i>
                    <span>اتصالك محمي ومشفر بالكامل ببروتوكول TLS 1.3 وتشفير AES-256</span>
                </div>
            </div>
        </div>
    </div>
</div>
