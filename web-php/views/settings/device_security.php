<?php
/**
 * Device Owner & Anti-Tamper Enterprise Security Hub
 * الحماية القصوى ومكافحة التلاعب وتنبيهات تبديل الـ SIM ووضع الطيران
 */
declare(strict_types=1);
?>
<section class="panel-card" id="deviceSecuritySection">
    <div class="panel-card-header">
        <div class="panel-title-group">
            <i class="fa-solid fa-shield-halved" style="color: var(--accent-purple); font-size: 1.5rem;"></i>
            <div>
                <h3>الحماية القصوى ومكافحة التلاعب (Anti-Tamper & Device Owner)</h3>
                <span class="sub-text">إدارة صلاحيات وضع مالك الجهاز (Device Owner) وتنبيهات العبث بالشريحة ووضع الطيران</span>
            </div>
        </div>
        <div class="header-actions">
            <button class="btn btn-outline btn-sm" onclick="requestDeviceOwnerStatus()">
                <i class="fa-solid fa-arrows-rotate"></i>
                <span>تحديث الحالة</span>
            </button>
            <button class="btn btn-primary btn-sm" onclick="openDeviceOwnerModal()" style="background: linear-gradient(135deg, #7c3aed, #a855f7); border: none;">
                <i class="fa-solid fa-qrcode"></i>
                <span>دليل تثبيت Device Owner</span>
            </button>
        </div>
    </div>

    <!-- Security Status Highlights Grid -->
    <div class="security-status-grid" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1rem; margin-top: 1.25rem;">
        
        <!-- Device Owner Status Card -->
        <div class="sec-card" style="background: var(--bg-surface); border: 1px solid var(--border-color); border-radius: var(--radius-md); padding: 1.25rem;">
            <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 0.75rem;">
                <div>
                    <h4 style="font-size: 1rem; font-weight: 700; color: var(--text-primary);"><i class="fa-solid fa-building-user" style="color: var(--accent-purple); margin-left: 6px;"></i> وضع مالك الجهاز (Device Owner)</h4>
                    <span style="font-size: 0.8rem; color: var(--text-muted);">Android Enterprise Managed Profile</span>
                </div>
                <span class="status-badge" id="badgeDeviceOwner" style="background: rgba(107, 114, 128, 0.2); color: var(--text-muted);">جاري الفحص...</span>
            </div>
            <p style="font-size: 0.85rem; color: var(--text-secondary); line-height: 1.4;">
                يمنح التطبيق أعلى سلطة حماية على مستوى نظام أندرويد لمنع إيقاف الحماية وحظر إلغاء التثبيت وفرض تشغيل إمكانية الوصول والموقع دائماً.
            </p>
        </div>

        <!-- SIM Swap Alert Card -->
        <div class="sec-card" style="background: var(--bg-surface); border: 1px solid var(--border-color); border-radius: var(--radius-md); padding: 1.25rem;">
            <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 0.75rem;">
                <div>
                    <h4 style="font-size: 1rem; font-weight: 700; color: var(--text-primary);"><i class="fa-solid fa-sim-card" style="color: var(--accent-cyan); margin-left: 6px;"></i> كاشف تبديل شريحة الـ SIM</h4>
                    <span style="font-size: 0.8rem; color: var(--text-muted);">SIM Swap & Removal Watcher</span>
                </div>
                <span class="status-badge" id="badgeSimWatcher" style="background: rgba(16, 185, 129, 0.2); color: #10b981;">نشط ومحمي 🟢</span>
            </div>
            <p style="font-size: 0.85rem; color: var(--text-secondary); line-height: 1.4;">
                يرصد إزالة أو استبدال الشريحة فوراً، ويطلق صفارة إنذار داخلية ويرسل إشعاراً عاجلاً للوحة التحكم مع بيانات المشغل الجديد.
            </p>
        </div>

        <!-- Airplane Mode Alert Card -->
        <div class="sec-card" style="background: var(--bg-surface); border: 1px solid var(--border-color); border-radius: var(--radius-md); padding: 1.25rem;">
            <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 0.75rem;">
                <div>
                    <h4 style="font-size: 1rem; font-weight: 700; color: var(--text-primary);"><i class="fa-solid fa-plane" style="color: var(--accent-amber); margin-left: 6px;"></i> كاشف وضع الطيران</h4>
                    <span style="font-size: 0.8rem; color: var(--text-muted);">Airplane Mode Watcher</span>
                </div>
                <span class="status-badge" id="badgeAirplaneWatcher" style="background: rgba(16, 185, 129, 0.2); color: #10b981;">نشط ومحمي 🟢</span>
            </div>
            <p style="font-size: 0.85rem; color: var(--text-secondary); line-height: 1.4;">
                يرصد محاولات الطفل لقطع الاتصال عبر وضع الطيران ويطلق تنبيهاً محلياً ويخزن الحدث للإرسال الفوري بمجرد التقاط الشبكة.
            </p>
        </div>

    </div>

    <!-- Active Enterprise Security Restrictions Table -->
    <div style="margin-top: 1.5rem; background: var(--bg-surface); border: 1px solid var(--border-color); border-radius: var(--radius-md); padding: 1.25rem;">
        <h4 style="font-size: 1rem; font-weight: 700; margin-bottom: 1rem; display: flex; align-items: center; gap: 8px;">
            <i class="fa-solid fa-lock" style="color: var(--accent-emerald);"></i>
            <span>القيود الأمنية المفروضة على الهاتف (Enterprise Security Policy)</span>
        </h4>

        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1rem;">
            <div style="background: rgba(255,255,255,0.03); border: 1px solid var(--border-light); border-radius: var(--radius-sm); padding: 0.85rem; display: flex; align-items: center; gap: 0.75rem;">
                <i class="fa-solid fa-ban" style="color: var(--accent-rose); font-size: 1.2rem;"></i>
                <div>
                    <div style="font-weight: 700; font-size: 0.9rem;">حظر إلغاء التثبيت</div>
                    <div style="font-size: 0.8rem; color: var(--text-muted);" id="statUninstallBlock">مفعل (setUninstallBlocked)</div>
                </div>
            </div>
            <div style="background: rgba(255,255,255,0.03); border: 1px solid var(--border-light); border-radius: var(--radius-sm); padding: 0.85rem; display: flex; align-items: center; gap: 0.75rem;">
                <i class="fa-solid fa-arrows-rotate" style="color: var(--accent-amber); font-size: 1.2rem;"></i>
                <div>
                    <div style="font-weight: 700; font-size: 0.9rem;">منع ضبط المصنع</div>
                    <div style="font-size: 0.8rem; color: var(--text-muted);" id="statFactoryReset">DISALLOW_FACTORY_RESET</div>
                </div>
            </div>
            <div style="background: rgba(255,255,255,0.03); border: 1px solid var(--border-light); border-radius: var(--radius-sm); padding: 0.85rem; display: flex; align-items: center; gap: 0.75rem;">
                <i class="fa-solid fa-power-off" style="color: var(--accent-cyan); font-size: 1.2rem;"></i>
                <div>
                    <div style="font-weight: 700; font-size: 0.9rem;">منع الوضع الآمن (Safe Boot)</div>
                    <div style="font-size: 0.8rem; color: var(--text-muted);" id="statSafeBoot">DISALLOW_SAFE_BOOT</div>
                </div>
            </div>
            <div style="background: rgba(255,255,255,0.03); border: 1px solid var(--border-light); border-radius: var(--radius-sm); padding: 0.85rem; display: flex; align-items: center; gap: 0.75rem;">
                <i class="fa-solid fa-sliders" style="color: var(--accent-purple); font-size: 1.2rem;"></i>
                <div>
                    <div style="font-weight: 700; font-size: 0.9rem;">حظر إيقاف التطبيقات</div>
                    <div style="font-size: 0.8rem; color: var(--text-muted);" id="statAppsControl">DISALLOW_APPS_CONTROL</div>
                </div>
            </div>
        </div>
    </div>
</section>
