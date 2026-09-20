<?php
/**
 * Remote Quick Actions Bar Component
 */
declare(strict_types=1);
?>
<section class="quick-actions-card">
    <div class="card-header-simple">
        <i class="fa-solid fa-bolt-lightning" style="color: var(--accent-amber)"></i>
        <h3>أوامر التحكم الفوري عن بُعد (Remote Instant Controls)</h3>
    </div>
    
    <!-- Master Monitoring Switch Banner -->
    <div class="master-monitoring-banner" id="masterMonitoringBanner">
        <div class="master-monitoring-info">
            <div class="master-icon-wrap active" id="masterMonitoringIcon">
                <i class="fa-solid fa-shield-halved"></i>
            </div>
            <div class="master-text-block">
                <div class="master-title-row">
                    <h4 id="masterMonitoringStatusText">درع حماية سَنَد نشط بالكامل</h4>
                    <span class="status-badge status-badge-active" id="masterMonitoringBadge">نشطة 🟢</span>
                </div>
                <p class="master-subtitle" id="masterMonitoringDesc">
                    كافة أدوات حماية التطبيقات، وتصفية الويب، والتقاط التنبيهات، وتتبع الجهاز تعمل بشكل طبيعي ومحكم.
                </p>
            </div>
        </div>
        <button class="btn-master-toggle btn-master-pause" id="btnMasterToggleMonitoring" onclick="toggleMasterMonitoring()">
            <i class="fa-solid fa-pause" id="masterToggleBtnIcon"></i>
            <span id="masterToggleBtnText">تعليق الحماية مؤقتاً</span>
        </button>
    </div>

    <div class="actions-buttons-grid">
        <!-- Silent Screenshot -->
        <button class="action-btn btn-highlight" onclick="requestScreenshot()">
            <div class="btn-icon"><i class="fa-solid fa-camera"></i></div>
            <div class="btn-labels">
                <span class="btn-primary-text">لقطة شاشة صامتة فورية</span>
                <span class="btn-secondary-text">Silent Screenshot</span>
            </div>
        </button>

        <!-- Live Camera Stream -->
        <button class="action-btn btn-cyan" onclick="switchSection('live-stream')">
            <div class="btn-icon"><i class="fa-solid fa-video"></i></div>
            <div class="btn-labels">
                <span class="btn-primary-text">بث الكاميرا المباشر</span>
                <span class="btn-secondary-text">Live WebRTC Camera</span>
            </div>
        </button>

        <!-- Live Screen Stream -->
        <button class="action-btn" style="background: linear-gradient(135deg, #4f46e5, #6366f1); border-color: #6366f1;" onclick="switchSection('live-screen'); startLiveScreenStream();">
            <div class="btn-icon"><i class="fa-solid fa-desktop" style="color: #fff;"></i></div>
            <div class="btn-labels">
                <span class="btn-primary-text" style="color: #fff;">عرض شاشة الطفل الحية</span>
                <span class="btn-secondary-text" style="color: rgba(255,255,255,0.8);">Live Screen Mirroring</span>
            </div>
        </button>

        <!-- Ambient Audio Listening -->
        <button class="action-btn btn-emerald" onclick="switchSection('ambient-audio'); toggleAmbientAudioStream();">
            <div class="btn-icon"><i class="fa-solid fa-microphone-lines"></i></div>
            <div class="btn-labels">
                <span class="btn-primary-text">استماع صوت المحيط</span>
                <span class="btn-secondary-text">Ambient Audio</span>
            </div>
        </button>

        <!-- Walkie-Talkie PTT -->
        <button class="action-btn btn-cyan" onclick="switchSection('walkie-talkie');">
            <div class="btn-icon"><i class="fa-solid fa-walkie-talkie"></i></div>
            <div class="btn-labels">
                <span class="btn-primary-text">اللاسلكي الفوري (PTT)</span>
                <span class="btn-secondary-text">Push-to-Talk Loudspeaker</span>
            </div>
        </button>

        <!-- Lock Device -->
        <button class="action-btn btn-danger" onclick="sendCommand('LOCK_DEVICE')">
            <div class="btn-icon"><i class="fa-solid fa-lock"></i></div>
            <div class="btn-labels">
                <span class="btn-primary-text">قفل الجهاز فوراً</span>
                <span class="btn-secondary-text">Lock Device</span>
            </div>
        </button>

        <!-- Unlock Device -->
        <button class="action-btn btn-emerald" onclick="sendCommand('UNLOCK_DEVICE')">
            <div class="btn-icon"><i class="fa-solid fa-lock-open"></i></div>
            <div class="btn-labels">
                <span class="btn-primary-text">إلغاء قفل الجهاز</span>
                <span class="btn-secondary-text">Unlock Device</span>
            </div>
        </button>

        <!-- Play Siren Alarm -->
        <button class="action-btn btn-amber" onclick="sendCommand('PLAY_ALARM')">
            <div class="btn-icon"><i class="fa-solid fa-bullhorn"></i></div>
            <div class="btn-labels">
                <span class="btn-primary-text">إطلاق صفارة إنذار</span>
                <span class="btn-secondary-text">Play Siren Alarm</span>
            </div>
        </button>

        <!-- Stop Siren Alarm -->
        <button class="action-btn btn-secondary" onclick="sendCommand('STOP_ALARM')">
            <div class="btn-icon"><i class="fa-solid fa-volume-xmark"></i></div>
            <div class="btn-labels">
                <span class="btn-primary-text">إيقاف الصفارة</span>
                <span class="btn-secondary-text">Mute Alarm</span>
            </div>
        </button>

        <!-- Anti-Uninstall Shield -->
        <button class="action-btn btn-danger" id="btnAntiUninstall" onclick="toggleAntiUninstall()">
            <div class="btn-icon"><i class="fa-solid fa-shield-halved"></i></div>
            <div class="btn-labels">
                <span class="btn-primary-text" id="antiUninstallBtnText">حظر إزالة التطبيق</span>
                <span class="btn-secondary-text">Anti-Uninstall Shield</span>
            </div>
        </button>

        <!-- Stealth Mode (Hide/Show Icon) -->
        <button class="action-btn btn-secondary" id="btnStealthMode" onclick="toggleStealthMode()">
            <div class="btn-icon"><i class="fa-solid fa-eye-slash"></i></div>
            <div class="btn-labels">
                <span class="btn-primary-text" id="stealthModeBtnText">وضع التخفي (إخفاء الأيقونة)</span>
                <span class="btn-secondary-text">Stealth Mode (*#*#2026#*#*)</span>
            </div>
        </button>

        <!-- Block Android Settings -->
        <button class="action-btn btn-amber" id="btnBlockSettings" onclick="toggleBlockSettings()">
            <div class="btn-icon"><i class="fa-solid fa-sliders"></i></div>
            <div class="btn-labels">
                <span class="btn-primary-text" id="blockSettingsBtnText">حظر إعدادات الجهاز</span>
                <span class="btn-secondary-text">Block Android Settings</span>
            </div>
        </button>

        <!-- Sync All Data -->
        <button class="action-btn btn-outline" onclick="requestFullSync()">
            <div class="btn-icon"><i class="fa-solid fa-rotate"></i></div>
            <div class="btn-labels">
                <span class="btn-primary-text">مزامنة كافة البيانات</span>
                <span class="btn-secondary-text">Fetch All Logs</span>
            </div>
        </button>
    </div>
</section>
