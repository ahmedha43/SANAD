<?php
/**
 * Delete Device & Unpair Confirmation Modal Component
 * حذف الجهاز وفك كافة القيود نهائياً
 */
declare(strict_types=1);
?>
<div class="modal-overlay" id="deleteDeviceModal" style="display: none;">
    <div class="modal-box modal-md" style="border: 1px solid rgba(239, 68, 68, 0.4); box-shadow: 0 20px 50px rgba(0,0,0,0.8), 0 0 30px rgba(239, 68, 68, 0.2);">
        <div class="modal-header" style="background: linear-gradient(135deg, rgba(239, 68, 68, 0.15) 0%, rgba(15, 23, 42, 0.95) 100%); border-bottom: 1px solid rgba(239, 68, 68, 0.25);">
            <div class="modal-title" style="color: #ef4444; display: flex; align-items: center; gap: 10px;">
                <div style="width: 38px; height: 38px; border-radius: 10px; background: rgba(239, 68, 68, 0.2); display: flex; align-items: center; justify-content: center; border: 1px solid rgba(239, 68, 68, 0.4);">
                    <i class="fa-solid fa-triangle-exclamation" style="font-size: 1.15rem; color: #ef4444;"></i>
                </div>
                <div>
                    <h3 style="margin: 0; font-size: 1.15rem; font-weight: 800; color: #ffffff;">حذف الجهاز وفك كافة القيود نهائياً</h3>
                    <span style="font-size: 0.78rem; color: #f87171;">إلغاء اقتران دائم ومسح شامل لبيانات الجهاز والرقابة</span>
                </div>
            </div>
            <button class="modal-close-btn" onclick="closeModal('deleteDeviceModal')">✕</button>
        </div>

        <div class="modal-body" style="padding: 1.5rem;">
            <!-- Target Device Badge -->
            <div style="background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 12px; padding: 1rem; display: flex; align-items: center; gap: 12px; margin-bottom: 1.25rem;">
                <div style="width: 44px; height: 44px; border-radius: 10px; background: linear-gradient(135deg, #ef4444 0%, #991b1b 100%); display: flex; align-items: center; justify-content: center; color: #ffffff; font-size: 1.3rem;">
                    <i class="fa-solid fa-mobile-screen-button" id="deleteTargetIcon"></i>
                </div>
                <div style="flex: 1;">
                    <div style="font-weight: 800; font-size: 1.05rem; color: #ffffff;" id="deleteTargetChildName">اسم الطفل</div>
                    <div style="font-size: 0.82rem; color: var(--text-muted);" id="deleteTargetDeviceInfo">موديل الجهاز - المعرف</div>
                </div>
                <span style="background: rgba(239, 68, 68, 0.15); color: #f87171; border: 1px solid rgba(239, 68, 68, 0.3); padding: 4px 10px; border-radius: 9999px; font-size: 0.75rem; font-weight: 700;">
                    سيتم الحذف نهائياً
                </span>
            </div>

            <!-- Danger Warning Notice -->
            <div style="background: rgba(239, 68, 68, 0.08); border-right: 4px solid #ef4444; border-radius: 8px; padding: 0.9rem 1.1rem; margin-bottom: 1.25rem;">
                <div style="font-weight: 800; font-size: 0.92rem; color: #fca5a5; margin-bottom: 6px; display: flex; align-items: center; gap: 6px;">
                    <i class="fa-solid fa-circle-exclamation"></i>
                    <span>ماذا يحدث عند تنفيذ هذا الإجراء؟</span>
                </div>
                <ul style="margin: 0; padding-right: 1.2rem; font-size: 0.83rem; color: #e2e8f0; line-height: 1.7;">
                    <li><b>فك جميع القيود فوراً:</b> رفع حظر كافة التطبيقات، وإلغاء حظر المواقع، وفك قفل الشاشة ومواعيد النوم.</li>
                    <li><b>إزالة حماية المالك (Device Owner):</b> إزالة الحظر عن إلغاء تثبيت التطبيق وتمكين حذف الأيجنت من الهاتف بحرية.</li>
                    <li><b>مسح بيانات الأيجنت:</b> تصفير قاعدة بيانات الهاتف المحلية وإلغاء مفاتيح التشفير وإيقاف الخدمات.</li>
                    <li><b>مسح شامل من السحابة:</b> حذف سجل المواقع، المكالمات، الرسائل، الصور، سجل التصفح والتنبيهات نهائياً.</li>
                </ul>
            </div>

            <p style="font-size: 0.85rem; color: var(--text-muted); line-height: 1.5; margin-bottom: 1.25rem;">
                ⚠️ هذا الإجراء فوري ونهائي ولا يمكن التراجع عنه. إذا كنت ترغب في إعادة مراقبة هذا الهاتف مستقبلاً، سيتعين عليك مسح رمز الاقتران من جديد وإعادة تثبيته.
            </p>

            <input type="hidden" id="deleteTargetDeviceId" value="">

            <div style="display: flex; gap: 10px; justify-content: flex-end;">
                <button type="button" class="btn btn-secondary" onclick="closeModal('deleteDeviceModal')" style="padding: 0.65rem 1.25rem; font-weight: 600;">
                    إلغاء التراجع
                </button>
                <button type="button" class="btn btn-danger" id="btnConfirmDeleteDevice" onclick="executeDeviceCompleteDeletion()" style="background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%); color: #ffffff; border: none; padding: 0.65rem 1.5rem; font-weight: 800; border-radius: var(--radius-sm); display: inline-flex; align-items: center; gap: 8px; box-shadow: 0 4px 15px rgba(239, 68, 68, 0.4); cursor: pointer;">
                    <i class="fa-solid fa-trash-can"></i>
                    <span>نعم، احذف وفك كافة القيود نهائياً</span>
                </button>
            </div>
        </div>
    </div>
</div>
