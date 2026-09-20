<?php
/**
 * Gallery & Files Explorer Component
 */
declare(strict_types=1);
?>
<section class="panel-card" id="gallerySection">
    <div class="panel-card-header">
        <div class="panel-title-group">
            <i class="fa-solid fa-images" style="color: var(--accent-purple)"></i>
            <div>
                <h3>معرض الصور والوسائط (Media Gallery & Files)</h3>
                <span class="sub-text">استعراض الصور الملتقطة ومحتويات المعرض على جهاز الطفل</span>
            </div>
        </div>
        <button class="btn btn-outline-sm" onclick="requestFilesSync()">
            <i class="fa-solid fa-arrows-rotate"></i>
            <span>طلب مزامنة الصور</span>
        </button>
    </div>

    <!-- Gallery Grid -->
    <div class="gallery-grid" id="galleryGridContainer">
        <div class="text-center text-muted" style="grid-column: 1/-1; padding: 40px;">
            <i class="fa-solid fa-images" style="font-size: 2.5rem; margin-bottom: 10px; opacity: 0.3;"></i>
            <div>جاري تحميل معرض الوسائط...</div>
        </div>
    </div>
</section>
