<?php
/**
 * Device Owner Setup & Provisioning Guide Modal
 * نافذة تفعيل الحماية القصوى ومكافحة التلاعب (Anti-Tamper & Device Owner)
 */
declare(strict_types=1);
?>
<div class="modal-overlay" id="deviceOwnerModal" style="display: none;">
    <div class="modal-box modal-lg" style="max-width: 720px; max-height: 90vh; overflow-y: auto;">
        <div class="modal-header">
            <div class="modal-title">
                <i class="fa-solid fa-shield-halved" style="color: var(--accent-purple)"></i>
                <span>تفعيل الحماية القصوى ومكافحة التلاعب (Anti-Tamper & Device Owner)</span>
            </div>
            <button class="modal-close-btn" onclick="closeModal('deviceOwnerModal')">✕</button>
        </div>
        <div class="modal-body" style="text-align: right;">
            
            <!-- Explainer -->
            <p style="font-size: 0.9rem; color: var(--text-secondary); line-height: 1.6; margin-bottom: 1.25rem;">
                تفعيل التطبيق كـ <strong>مالك الجهاز (Device Owner)</strong> عبر نظام <strong>Android Enterprise</strong> يمنح التطبيق الحصانة المطلقة ضد أي محاولة تلاعب من قبل الطفل؛ حيث يستحيل عليه مسح التطبيق أو إيقاف الصلاحيات أو عمل فورمات للجهاز.
            </p>

            <!-- Protections Table -->
            <div style="background: rgba(255, 255, 255, 0.03); border: 1px solid var(--border-color); border-radius: var(--radius-md); padding: 1rem; margin-bottom: 1.25rem;">
                <h4 style="font-size: 0.95rem; font-weight: 700; color: var(--text-primary); margin-bottom: 0.75rem; display: flex; align-items: center; gap: 8px;">
                    <i class="fa-solid fa-list-check" style="color: var(--accent-emerald);"></i>
                    <span>جدول حالة الحمايات المؤسسية (Protection Status Matrix)</span>
                </h4>
                <div style="overflow-x: auto;">
                    <table style="width: 100%; border-collapse: collapse; font-size: 0.85rem; text-align: right;">
                        <thead>
                            <tr style="border-bottom: 1px solid var(--border-light); color: var(--text-muted);">
                                <th style="padding: 6px 8px;">نوع الحماية</th>
                                <th style="padding: 6px 8px;">السياسة البرمجية</th>
                                <th style="padding: 6px 8px; text-align: center;">الحالة</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr style="border-bottom: 1px solid rgba(255,255,255,0.05);">
                                <td style="padding: 8px;"><i class="fa-solid fa-ban" style="color: var(--accent-rose); margin-left: 6px;"></i> <strong>منع حذف التطبيق نهائياً</strong></td>
                                <td style="padding: 8px; color: var(--text-muted); font-family: monospace;">setUninstallBlocked</td>
                                <td style="padding: 8px; text-align: center;"><span class="status-badge" style="background: rgba(16, 185, 129, 0.2); color: #10b981;">مفعل 🔒</span></td>
                            </tr>
                            <tr style="border-bottom: 1px solid rgba(255,255,255,0.05);">
                                <td style="padding: 8px;"><i class="fa-solid fa-arrows-rotate" style="color: var(--accent-amber); margin-left: 6px;"></i> <strong>منع ضبط المصنع (الفورمات)</strong></td>
                                <td style="padding: 8px; color: var(--text-muted); font-family: monospace;">DISALLOW_FACTORY_RESET</td>
                                <td style="padding: 8px; text-align: center;"><span class="status-badge" style="background: rgba(16, 185, 129, 0.2); color: #10b981;">مفعل 🔒</span></td>
                            </tr>
                            <tr style="border-bottom: 1px solid rgba(255,255,255,0.05);">
                                <td style="padding: 8px;"><i class="fa-solid fa-power-off" style="color: var(--accent-cyan); margin-left: 6px;"></i> <strong>منع الوضع الآمن (Safe Boot)</strong></td>
                                <td style="padding: 8px; color: var(--text-muted); font-family: monospace;">DISALLOW_SAFE_BOOT</td>
                                <td style="padding: 8px; text-align: center;"><span class="status-badge" style="background: rgba(16, 185, 129, 0.2); color: #10b981;">مفعل 🔒</span></td>
                            </tr>
                            <tr>
                                <td style="padding: 8px;"><i class="fa-solid fa-user-shield" style="color: var(--accent-purple); margin-left: 6px;"></i> <strong>منع إيقاف الوصول والموقع</strong></td>
                                <td style="padding: 8px; color: var(--text-muted); font-family: monospace;">DISALLOW_APPS_CONTROL</td>
                                <td style="padding: 8px; text-align: center;"><span class="status-badge" style="background: rgba(16, 185, 129, 0.2); color: #10b981;">مفعل 🔒</span></td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>

            <!-- Method 1: Instant ADB Command -->
            <div style="background: rgba(255, 255, 255, 0.03); border: 1px solid var(--border-color); border-radius: var(--radius-md); padding: 1.25rem; margin-bottom: 1.25rem;">
                <h4 style="font-size: 0.95rem; font-weight: 700; color: var(--accent-cyan); margin-bottom: 0.5rem; display: flex; align-items: center; justify-content: space-between;">
                    <span><i class="fa-solid fa-terminal" style="margin-left: 6px;"></i> الطريقة الأولى: أمر ADB الجاهز (نسخة واحدة - 30 ثانية)</span>
                    <span style="font-size: 0.75rem; color: #10b981; background: rgba(16,185,129,0.15); padding: 2px 8px; border-radius: 4px;">موصى به</span>
                </h4>
                <p style="font-size: 0.85rem; color: var(--text-muted); margin-bottom: 0.75rem;">
                    صل جهاز الطفل بالكمبيوتر عبر كابل USB مع تفعيل تصحيح USB (USB Debugging)، ثم نفذ الأمر التالي:
                </p>
                <div style="background: #000; border: 1px solid var(--border-light); border-radius: var(--radius-sm); padding: 0.75rem 1rem; display: flex; align-items: center; justify-content: space-between; gap: 0.5rem; direction: ltr; font-family: monospace;">
                    <code id="adbCommandText" style="color: #38bdf8; font-size: 0.85rem; word-break: break-all;">adb shell dpm set-device-owner com.parentalcontrol.kidsagent/.service.AgentDeviceAdminReceiver</code>
                    <button class="btn btn-sm btn-outline" onclick="copyAdbCommand()" title="نسخ الأمر" style="padding: 5px 12px; font-size: 0.85rem; flex-shrink: 0; background: rgba(56, 189, 248, 0.1); border-color: #38bdf8; color: #38bdf8;">
                        <i class="fa-solid fa-copy"></i>
                        <span id="copyAdbBtnText">نسخ الأمر</span>
                    </button>
                </div>
                <div style="font-size: 0.8rem; color: var(--accent-amber); margin-top: 0.6rem; line-height: 1.4;">
                    <i class="fa-solid fa-circle-info"></i> ملاحظة أندرويد: إذا ظهر خطأ <code>already some accounts on the device</code>، توجه إلى إعدادات الجهاز > الحسابات، وقم بإزالة حسابات Google مؤقتاً، ونفذ الأمر، ثم أعد إضافة الحسابات.
                </div>
            </div>

            <!-- Method 2: QR Code Provisioning -->
            <div style="background: rgba(255, 255, 255, 0.03); border: 1px solid var(--border-color); border-radius: var(--radius-md); padding: 1.25rem;">
                <h4 style="font-size: 0.95rem; font-weight: 700; color: var(--accent-emerald); margin-bottom: 0.5rem;">
                    <i class="fa-solid fa-qrcode" style="margin-left: 6px;"></i> الطريقة الثانية: رمز QR للتهيئة المباشرة بعد الفورمات
                </h4>
                <p style="font-size: 0.85rem; color: var(--text-muted); margin-bottom: 1rem;">
                    عند تشغيل الجهاز لأول مرة أو بعد ضبط المصنع، اضغط <strong>6 مرات متتالية</strong> على شاشة الترحيب البيضاء (Welcome Screen) لتشغيل كاميرا الـ QR، ثم امسح الرمز أدناه لتثبيت التطبيق تلقائياً كـ Device Owner:
                </p>
                <div style="display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 0.75rem; background: #fff; padding: 1rem; border-radius: var(--radius-md); width: 200px; margin: 0 auto;">
                    <div id="deviceOwnerQrCanvas"></div>
                </div>
                <div style="text-align: center; margin-top: 0.75rem; font-size: 0.8rem; color: var(--text-muted);">
                    تكوين Android Enterprise DPC Provisioning جاهز وموثق
                </div>
            </div>

            <div class="modal-footer-simple" style="margin-top: 1.5rem; display: flex; justify-content: flex-end; gap: 0.75rem;">
                <button class="btn btn-secondary" onclick="closeModal('deviceOwnerModal')">إغلاق</button>
                <button class="btn btn-primary" onclick="requestDeviceOwnerStatus(); closeModal('deviceOwnerModal');">
                    <i class="fa-solid fa-check"></i>
                    <span>فحص وتحديث الحالة الحالية</span>
                </button>
            </div>
        </div>
    </div>
</div>

<script>
function renderDeviceOwnerQR() {
    const container = document.getElementById('deviceOwnerQrCanvas');
    if (!container || container.children.length > 0) return;
    if (typeof QRCode === 'undefined') return;

    const qrData = JSON.stringify({
        "android.app.extra.PROVISIONING_DEVICE_ADMIN_COMPONENT_NAME": "com.parentalcontrol.kidsagent/com.parentalcontrol.kidsagent.service.AgentDeviceAdminReceiver",
        "android.app.extra.PROVISIONING_LEAVE_ALL_SYSTEM_APPS_ENABLED": true,
        "android.app.extra.PROVISIONING_SKIP_ENCRYPTION": true
    });

    try {
        new QRCode(container, {
            text: qrData,
            width: 170,
            height: 170,
            colorDark: "#000000",
            colorLight: "#ffffff",
            correctLevel: QRCode.CorrectLevel.M
        });
    } catch(e) {
        console.warn('QR Render error:', e);
    }
}

// Auto render QR when modal opens
const origOpenDeviceOwnerModal = window.openDeviceOwnerModal;
window.openDeviceOwnerModal = function() {
    const modal = document.getElementById('deviceOwnerModal');
    if (modal) modal.style.display = 'flex';
    setTimeout(renderDeviceOwnerQR, 100);
};
</script>
