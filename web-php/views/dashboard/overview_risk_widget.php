<?php
/**
 * Overview Recent Risk Alerts Widget
 */
declare(strict_types=1);
?>
<section class="panel-card" id="overviewAlertsSection">
    <div class="panel-card-header">
        <div class="panel-title-group">
            <i class="fa-solid fa-shield-virus" style="color: var(--accent-rose)"></i>
            <div>
                <h3>أحدث تنبيهات الأمان (AI Alerts)</h3>
                <span class="sub-text">رصد ذكي للأنشطة الحساسة</span>
            </div>
        </div>
        <span class="badge badge-danger" id="overviewRisksBadge">0</span>
    </div>

    <!-- Overview Risk Stream List -->
    <div class="alerts-stream-container" id="overviewRiskAlertsList" style="padding: 14px; max-height: 420px; overflow-y: auto;">
        <div class="text-center text-muted" style="padding: 30px 10px;">
            <i class="fa-solid fa-spinner fa-spin" style="font-size: 1.5rem; color: var(--accent-rose); margin-bottom: 8px; display: block;"></i>
            <div>جاري فحص التنبيهات...</div>
        </div>
    </div>

    <div class="panel-card-footer" style="padding: 12px 16px; border-top: 1px solid var(--border-color); text-align: center; background: rgba(0,0,0,0.1);">
        <button class="btn btn-outline-sm btn-block" onclick="switchSection('alerts')" style="width: 100%; justify-content: center;">
            <i class="fa-solid fa-arrow-left"></i>
            <span id="overviewAlertsViewAllText">عرض كافة التنبيهات والتحكم الكامل (0)</span>
        </button>
    </div>
</section>
