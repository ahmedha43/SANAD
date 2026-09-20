<?php
/**
 * Media Full Preview Modal Component
 */
declare(strict_types=1);
?>
<div class="modal-overlay" id="mediaModal" style="display: none;">
    <div class="modal-box modal-lg">
        <div class="modal-header">
            <div class="modal-title" id="mediaModalTitle">
                <i class="fa-solid fa-image" style="color: var(--accent-cyan)"></i>
                <span>معاينة الصورة الأصلية</span>
            </div>
            <button class="modal-close-btn" onclick="closeModal('mediaModal')">✕</button>
        </div>
        <div class="modal-body modal-media-body">
            <img id="mediaModalImage" src="" alt="Photo Full Preview" class="modal-preview-img">
        </div>
        <div class="modal-footer-bar">
            <span class="media-meta-text" id="mediaModalMeta">الملف: image.jpg</span>
            <a id="mediaModalDownloadBtn" href="#" download class="btn btn-primary-sm">
                <i class="fa-solid fa-download"></i>
                <span>تحميل الصورة</span>
            </a>
        </div>
    </div>
</div>
