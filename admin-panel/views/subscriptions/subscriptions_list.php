<?php
/**
 * Admin Panel - Subscriptions & Licenses Component
 */
declare(strict_types=1);
?>
<section id="tab-subscriptions" class="hidden">
    <div class="rounded-2xl bg-gray-900/50 border border-gray-800 glass overflow-hidden">
        <div class="p-5 border-b border-gray-800/80 flex items-center justify-between">
            <div>
                <h3 class="font-bold text-white text-base">إدارة التراخيص والاشتراكات العائلية</h3>
                <p class="text-xs text-gray-500">متابعة الباقات الفعالة والحد الأقصى للأجهزة وصلاحيات الاشتراك</p>
            </div>
            <div class="flex items-center gap-3">
                <span class="px-3 py-1 rounded-lg bg-amber-500/10 text-amber-400 text-xs font-semibold border border-amber-500/20" id="subs-count-badge">
                    0 اشتراك
                </span>
            </div>
        </div>

        <div class="overflow-x-auto">
            <table class="w-full text-right text-sm">
                <thead class="bg-gray-800/30 text-gray-400 text-xs font-semibold border-b border-gray-800">
                    <tr>
                        <th class="py-3.5 px-5">العائلة وولي الأمر</th>
                        <th class="py-3.5 px-5">باقة الترخيص</th>
                        <th class="py-3.5 px-5">الأجهزة (المستهلك / الحد)</th>
                        <th class="py-3.5 px-5">تاريخ البدء</th>
                        <th class="py-3.5 px-5">تاريخ الانتهاء</th>
                        <th class="py-3.5 px-5">حالة الترخيص</th>
                        <th class="py-3.5 px-5 text-center">إجراءات الترخيص</th>
                    </tr>
                </thead>
                <tbody id="subs-table-body" class="divide-y divide-gray-800/50 text-gray-300">
                    <tr>
                        <td colspan="7" class="py-8 text-center text-gray-500">
                            <i class="fa-solid fa-spinner fa-spin ml-2"></i>
                            <span>جاري تحميل بيانات الاشتراكات...</span>
                        </td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>
</section>
