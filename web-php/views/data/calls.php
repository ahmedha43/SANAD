<?php
/**
 * Calls Log Explorer Component
 */
declare(strict_types=1);
?>
<section class="panel-card" id="callsSection">
    <div class="panel-card-header">
        <div class="panel-title-group">
            <i class="fa-solid fa-phone-volume" style="color: var(--accent-emerald)"></i>
            <div>
                <h3>سجل المكالمات الهاتفية (Phone Calls Log)</h3>
                <span class="sub-text">سجل المكالمات الصادرة والواردة والفائتة مع تفاصيل المدة والتوقيت الدقيق</span>
            </div>
        </div>
        <button class="btn btn-outline-sm" onclick="requestCallsSync()">
            <i class="fa-solid fa-arrows-rotate"></i>
            <span>طلب مزامنة المكالمات</span>
        </button>
    </div>

    <div class="table-responsive">
        <table class="modern-table">
            <thead>
                <tr>
                    <th>جهة الاتصال / الرقم</th>
                    <th>نوع المكالمة</th>
                    <th>المدة</th>
                    <th>التاريخ والوقت</th>
                    <th>التسجيل / الصوت</th>
                </tr>
            </thead>
            <tbody id="callsTableBody">
                <tr>
                    <td colspan="5" class="text-center text-muted">جاري تحميل سجل المكالمات...</td>
                </tr>
            </tbody>
        </table>
    </div>
</section>
