<?php
/**
 * Gallery & Device Files Explorer Component
 * Supports Media Gallery with Base64 thumbnails + Full File Explorer & Direct File Transfer
 */
declare(strict_types=1);
?>
<section class="panel-card" id="gallerySection">
    <!-- View Switcher Tabs -->
    <div style="display: flex; gap: 10px; border-bottom: 1px solid var(--border-color); padding-bottom: 14px; margin-bottom: 20px;">
        <button id="tabBtnGallery" class="btn btn-primary-sm" onclick="App.switchFilesView('gallery')" style="display: flex; align-items: center; gap: 8px;">
            <i class="fa-solid fa-images"></i>
            <span>معرض الصور والوسائط</span>
            <span class="badge bg-secondary" id="filesTabCountBadge" style="margin-right: 4px;">0</span>
        </button>
        <button id="tabBtnExplorer" class="btn btn-outline-sm" onclick="App.switchFilesView('explorer')" style="display: flex; align-items: center; gap: 8px;">
            <i class="fa-solid fa-folder-tree"></i>
            <span>متصفح ونقل ملفات الجهاز (File Explorer)</span>
        </button>
    </div>

    <!-- VIEW 1: Media Gallery Grid -->
    <div id="viewGalleryContainer">
        <div class="panel-card-header" style="margin-bottom: 16px;">
            <div class="panel-title-group">
                <i class="fa-solid fa-images" style="color: var(--accent-purple)"></i>
                <div>
                    <h3>معرض الصور والوسائط الملتقطة</h3>
                    <span class="sub-text">استعراض أحدث الصور واللقطات ومقاطع الفيديو من هاتف الطفل بدقة حية</span>
                </div>
            </div>
            <div style="display: flex; gap: 8px;">
                <button class="btn btn-outline-sm" onclick="requestFilesSync()">
                    <i class="fa-solid fa-arrows-rotate"></i>
                    <span>طلب مزامنة المعرض</span>
                </button>
            </div>
        </div>

        <!-- Filter pills -->
        <div style="display: flex; gap: 8px; margin-bottom: 16px;">
            <button class="btn btn-outline-sm btn-filter active" id="filterAll" onclick="App.filterGallery('all')" style="font-size: 0.8rem; padding: 4px 12px;">الكل</button>
            <button class="btn btn-outline-sm btn-filter" id="filterImages" onclick="App.filterGallery('images')" style="font-size: 0.8rem; padding: 4px 12px;">الصور فقط</button>
            <button class="btn btn-outline-sm btn-filter" id="filterVideos" onclick="App.filterGallery('videos')" style="font-size: 0.8rem; padding: 4px 12px;">الفيديوهات</button>
        </div>

        <!-- Gallery Grid -->
        <div class="gallery-grid" id="galleryGridContainer">
            <div class="text-center text-muted" style="grid-column: 1/-1; padding: 40px;">
                <i class="fa-solid fa-images" style="font-size: 2.5rem; margin-bottom: 10px; opacity: 0.3;"></i>
                <div>جاري تحميل معرض الوسائط...</div>
            </div>
        </div>
    </div>

    <!-- VIEW 2: Device File Explorer & Direct Transfer -->
    <div id="viewExplorerContainer" style="display: none;">
        <div class="panel-card-header" style="margin-bottom: 14px;">
            <div class="panel-title-group">
                <i class="fa-solid fa-hard-drive" style="color: var(--accent-cyan)"></i>
                <div>
                    <h3>متصفح ملفات الهاتف ونقل البيانات (File Transfer)</h3>
                    <span class="sub-text">تصفح كافة مجلدات هاتف الطفل (التنزيلات، المستندات، الوسائط) وتحميل أي ملف بضغطة زر</span>
                </div>
            </div>
            <div style="display: flex; gap: 8px;">
                <button class="btn btn-outline-sm" onclick="App.refreshCurrentDirectory()">
                    <i class="fa-solid fa-arrows-rotate"></i>
                    <span>تحديث المجلد</span>
                </button>
            </div>
        </div>

        <!-- Quick Shortcuts -->
        <div style="display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 14px; background: rgba(255,255,255,0.02); padding: 10px 14px; border-radius: 8px; border: 1px solid var(--border-color);">
            <span style="font-size: 0.85rem; color: var(--text-secondary); margin-left: 6px; align-self: center;">اختصارات سريعة:</span>
            <button class="btn btn-outline-sm" onclick="App.navigateToDirectory('/storage/emulated/0/Download')" style="font-size: 0.8rem; padding: 4px 10px;">
                <i class="fa-solid fa-download" style="color: #38bdf8;"></i> التنزيلات (Download)
            </button>
            <button class="btn btn-outline-sm" onclick="App.navigateToDirectory('/storage/emulated/0/DCIM')" style="font-size: 0.8rem; padding: 4px 10px;">
                <i class="fa-solid fa-camera" style="color: #ec4899;"></i> كاميرا وصور (DCIM)
            </button>
            <button class="btn btn-outline-sm" onclick="App.navigateToDirectory('/storage/emulated/0/Documents')" style="font-size: 0.8rem; padding: 4px 10px;">
                <i class="fa-solid fa-file-lines" style="color: #10b981;"></i> المستندات (Documents)
            </button>
            <button class="btn btn-outline-sm" onclick="App.navigateToDirectory('/storage/emulated/0/Pictures')" style="font-size: 0.8rem; padding: 4px 10px;">
                <i class="fa-solid fa-image" style="color: #f59e0b;"></i> الصور (Pictures)
            </button>
            <button class="btn btn-outline-sm" onclick="App.navigateToDirectory('/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media')" style="font-size: 0.8rem; padding: 4px 10px;">
                <i class="fa-brands fa-whatsapp" style="color: #22c55e;"></i> وسائط واتساب
            </button>
            <button class="btn btn-outline-sm" onclick="App.navigateToDirectory('/storage/emulated/0')" style="font-size: 0.8rem; padding: 4px 10px;">
                <i class="fa-solid fa-house"></i> الرئيسية
            </button>
        </div>

        <!-- Path Bar & Up Button -->
        <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 16px; background: var(--bg-card); padding: 10px 14px; border-radius: 8px; border: 1px solid var(--border-color);">
            <button id="btnDirUp" class="btn btn-outline-sm" onclick="App.navigateDirectoryUp()" title="الرجوع للمجلد السابق">
                <i class="fa-solid fa-arrow-up"></i>
                <span>أعلى</span>
            </button>
            <div style="flex: 1; display: flex; align-items: center; gap: 8px; overflow-x: auto; white-space: nowrap; font-family: monospace; font-size: 0.9rem; color: var(--accent-cyan);" id="dirBreadcrumbsContainer">
                <i class="fa-solid fa-folder-open"></i>
                <span id="currentDirPath">/storage/emulated/0</span>
            </div>
        </div>

        <!-- Explorer Items Container -->
        <div id="explorerItemsContainer" style="min-height: 250px;">
            <div class="text-center text-muted" style="padding: 40px;">
                <i class="fa-solid fa-folder-tree" style="font-size: 2.5rem; margin-bottom: 10px; opacity: 0.3;"></i>
                <div>اضغط على "تحديث المجلد" أو اختر اختصاراً لتصفح ملفات الطفل</div>
            </div>
        </div>
    </div>
</section>
