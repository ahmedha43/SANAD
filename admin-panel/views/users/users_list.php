<?php
/**
 * Admin Panel - Users & Families List Component
 */
declare(strict_types=1);
?>
<section id="tab-users" class="hidden">
    <div class="rounded-2xl bg-gray-900/50 border border-gray-800 glass overflow-hidden">
        <div class="p-5 border-b border-gray-800/80 flex items-center justify-between">
            <div>
                <h3 class="font-bold text-white text-base">قائمة أولياء الأمور والعائلات</h3>
                <p class="text-xs text-gray-500">كافة الحسابات المسجلة وحالة باقات الاشتراك المرتبطة</p>
            </div>
            <div class="flex items-center gap-3">
                <span class="px-3 py-1 rounded-lg bg-blue-500/10 text-blue-400 text-xs font-semibold border border-blue-500/20" id="users-count-badge">
                    0 مستخدم
                </span>
            </div>
        </div>

        <div class="overflow-x-auto">
            <table class="w-full text-right text-sm">
                <thead class="bg-gray-800/30 text-gray-400 text-xs font-semibold border-b border-gray-800">
                    <tr>
                        <th class="py-3.5 px-5">اسم ولي الأمر</th>
                        <th class="py-3.5 px-5">البريد الإلكتروني</th>
                        <th class="py-3.5 px-5">رقم الهاتف</th>
                        <th class="py-3.5 px-5">العائلة</th>
                        <th class="py-3.5 px-5">باقة الاشتراك</th>
                        <th class="py-3.5 px-5">الأجهزة / الأطفال</th>
                        <th class="py-3.5 px-5">الدور</th>
                        <th class="py-3.5 px-5">تاريخ التسجيل</th>
                    </tr>
                </thead>
                <tbody id="users-table-body" class="divide-y divide-gray-800/50 text-gray-300">
                    <tr>
                        <td colspan="8" class="py-8 text-center text-gray-500">
                            <i class="fa-solid fa-spinner fa-spin ml-2"></i>
                            <span>جاري تحميل بيانات أولياء الأمور...</span>
                        </td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>
</section>
