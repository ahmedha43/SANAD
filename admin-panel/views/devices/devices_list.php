<?php
/**
 * Admin Panel - Connected Devices Component
 */
declare(strict_types=1);
?>
<section id="tab-devices" class="hidden">
    <div class="rounded-2xl bg-gray-900/50 border border-gray-800 glass overflow-hidden">
        <div class="p-5 border-b border-gray-800/80 flex items-center justify-between">
            <div>
                <h3 class="font-bold text-white text-base">أجهزة الأطفال المتصلة والمقترنة</h3>
                <p class="text-xs text-gray-500">مراقبة حالة البطارية، الاتصال، وتنفيذ أوامر الإدارة الفورية</p>
            </div>
            <div class="flex items-center gap-3">
                <span class="px-3 py-1 rounded-lg bg-purple-500/10 text-purple-400 text-xs font-semibold border border-purple-500/20" id="devices-count-badge">
                    0 جهاز
                </span>
            </div>
        </div>

        <div class="overflow-x-auto">
            <table class="w-full text-right text-sm">
                <thead class="bg-gray-800/30 text-gray-400 text-xs font-semibold border-b border-gray-800">
                    <tr>
                        <th class="py-3.5 px-5">اسم الطفل</th>
                        <th class="py-3.5 px-5">اسم وطراز الجهاز</th>
                        <th class="py-3.5 px-5">النظام</th>
                        <th class="py-3.5 px-5">البطارية</th>
                        <th class="py-3.5 px-5">الشبكة</th>
                        <th class="py-3.5 px-5">الحالة</th>
                        <th class="py-3.5 px-5">آخر اتصال</th>
                        <th class="py-3.5 px-5 text-center">أوامر التحكم الإداري</th>
                    </tr>
                </thead>
                <tbody id="devices-table-body" class="divide-y divide-gray-800/50 text-gray-300">
                    <tr>
                        <td colspan="8" class="py-8 text-center text-gray-500">
                            <i class="fa-solid fa-spinner fa-spin ml-2"></i>
                            <span>جاري تحميل بيانات الأجهزة...</span>
                        </td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>
</section>
