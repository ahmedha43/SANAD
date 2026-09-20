<?php
/**
 * SMS Messages Explorer Component
 */
declare(strict_types=1);
?>
<section class="panel-card" id="smsSection">
    <div class="panel-card-header">
        <div class="panel-title-group">
            <i class="fa-solid fa-comments" style="color: var(--accent-cyan)"></i>
            <div>
                <h3>الرسائل النصية القصيرة (SMS Messages)</h3>
                <span class="sub-text">استعراض الرسائل النصية المتبادلة مع فك التشفير التام (E2EE) محلياً</span>
            </div>
        </div>
        <button class="btn btn-outline-sm" onclick="requestSmsSync()">
            <i class="fa-solid fa-arrows-rotate"></i>
            <span>طلب مزامنة الرسائل</span>
        </button>
    </div>

    <div class="sms-explorer-layout">
        <!-- Messages Stream -->
        <div class="sms-stream" id="smsStreamContainer">
            <div class="text-center text-muted" style="padding: 30px;">جاري تحميل محادثات الرسائل القصيرة...</div>
        </div>
    </div>
</section>
