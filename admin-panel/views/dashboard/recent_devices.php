<?php
/**
 * Admin Panel - Recent Devices Table Component (Dashboard Tab)
 */
declare(strict_types=1);
?>
<div class="rounded-2xl bg-gray-900/50 border border-gray-800 glass overflow-hidden">
    <div class="p-5 border-b border-gray-800/80 flex items-center justify-between">
        <div>
            <h3 class="font-bold text-white text-sm">أحدث أجهزة الأطفال النشطة</h3>
            <p class="text-xs text-gray-500">حالة الاتصال ومستوى البطارية الحالي</p>
        </div>
        <button onclick="switchTab('devices')" class="text-xs text-blue-400 hover:text-blue-300 font-semibold flex items-center gap-1">
            <span>عرض كافة الأجهزة</span>
            <i class="fa-solid fa-arrow-left"></i>
        </button>
    </div>
    <div class="overflow-x-auto">
        <table class="w-full text-right text-sm">
            <thead class="bg-gray-800/30 text-gray-400 text-xs font-semibold border-b border-gray-800">
                <tr>
                    <th class="py-3.5 px-5">اسم الطفل</th>
                    <th class="py-3.5 px-5">طراز الجهاز</th>
                    <th class="py-3.5 px-5">النظام والشبكة</th>
                    <th class="py-3.5 px-5">البطارية</th>
                    <th class="py-3.5 px-5">حالة الاتصال</th>
                </tr>
            </thead>
            <tbody id="overview-devices-body" class="divide-y divide-gray-800/50 text-gray-300">
                <tr>
                    <td colspan="5" class="py-6 text-center text-gray-500">
                        <i class="fa-solid fa-spinner fa-spin ml-2"></i>
                        <span>جاري تحميل بيانات الأجهزة...</span>
                    </td>
                </tr>
            </tbody>
        </table>
    </div>
</div>
