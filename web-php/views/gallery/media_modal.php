<?php
/**
 * Media & File Full Preview / Transfer Modal Component
 */
declare(strict_types=1);
?>
<div class="modal-overlay" id="mediaModal" style="display: none;">
    <div class="modal-box modal-lg">
        <div class="modal-header">
            <div class="modal-title" id="mediaModalTitle">
                <i class="fa-solid fa-file-image" style="color: var(--accent-cyan)"></i>
                <span>معاينة وتحميل الملف</span>
            </div>
            <button class="modal-close-btn" onclick="closeModal('mediaModal')">✕</button>
        </div>
        <div class="modal-body modal-media-body" id="mediaModalBody" style="min-height: 250px; display: flex; align-items: center; justify-content: center; flex-direction: column;">
            <div id="mediaModalLoading" style="display: none; text-align: center; padding: 40px;">
                <i class="fa-solid fa-spinner fa-spin" style="font-size: 2.5rem; color: var(--accent-cyan); margin-bottom: 12px; display: block;"></i>
                <div style="color: var(--text-primary); font-weight: bold; margin-bottom: 6px;">جاري جلب الملف الأصلي من هاتف الطفل...</div>
                <div style="color: var(--text-secondary); font-size: 0.85rem;">يتم نقل البيانات مباشرة عبر القناة السحابية المشفرة</div>
            </div>
            <img id="mediaModalImage" src="" alt="Full Preview" class="modal-preview-img" style="display: none; max-width: 100%; max-height: 70vh; border-radius: 8px; object-fit: contain;">
            <div id="mediaModalFileContainer" style="display: none; text-align: center; padding: 30px;">
                <i id="mediaModalFileIcon" class="fa-solid fa-file-lines" style="font-size: 4rem; color: var(--accent-purple); margin-bottom: 16px;"></i>
                <div id="mediaModalFileName" style="font-size: 1.15rem; font-weight: bold; color: var(--text-primary); margin-bottom: 8px;"></div>
                <div id="mediaModalFileSize" style="color: var(--text-secondary); font-size: 0.9rem; margin-bottom: 16px;"></div>
            </div>
            <div id="mediaModalError" style="display: none; color: var(--accent-rose); text-align: center; padding: 30px;">
                <i class="fa-solid fa-circle-exclamation" style="font-size: 2.5rem; margin-bottom: 10px; display: block;"></i>
                <div id="mediaModalErrorText">تعذر استعراض الملف</div>
            </div>
        </div>
        <div class="modal-footer-bar">
            <span class="media-meta-text" id="mediaModalMeta">الملف: --</span>
            <button id="mediaModalDownloadBtn" class="btn btn-primary-sm" onclick="App.downloadActiveModalFile()" style="display: none;">
                <i class="fa-solid fa-download"></i>
                <span>تحميل الملف إلى جهازك</span>
            </button>
        </div>
    </div>
</div>
