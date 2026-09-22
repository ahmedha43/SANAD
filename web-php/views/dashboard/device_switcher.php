<?php
/**
 * Multi-Child / Multi-Device Switcher Component
 */
declare(strict_types=1);
?>
<section class="device-switcher-section">
    <div class="section-title-row">
        <div class="title-with-icon">
            <i class="fa-solid fa-users"></i>
            <h2>أجهزة العائلة والأطفال</h2>
        </div>
        <button class="btn btn-primary" onclick="openAddChildModal()">
            <i class="fa-solid fa-plus"></i>
            <span>إضافة طفل / جهاز جديد</span>
        </button>
    </div>

    <!-- Dynamic Scrollable Device List -->
    <div class="children-cards-container" id="childrenCardsContainer">
        <!-- Rendered dynamically by JS loadChildren() -->
        <div class="child-card-loading">
            <i class="fa-solid fa-circle-notch fa-spin"></i>
            <span>جاري تحميل بيانات أجهزة الأطفال...</span>
        </div>
    </div>

    <!-- Dynamic Unpaired Devices Quick Alert Bar -->
    <div id="unpairedDevicesQuickBar" style="display: none; margin-top: 12px;"></div>
</section>
