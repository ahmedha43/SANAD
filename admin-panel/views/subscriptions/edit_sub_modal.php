<?php
/**
 * Admin Panel - Edit Family Subscription Modal
 */
declare(strict_types=1);
?>
<div id="editSubModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4 hidden">
    <div class="bg-gray-900 border border-gray-800 rounded-2xl w-full max-w-lg overflow-hidden shadow-2xl animate-in fade-in zoom-in-95 duration-200">
        <!-- Header -->
        <div class="p-5 border-b border-gray-800 flex items-center justify-between">
            <h3 class="font-bold text-white text-base flex items-center gap-2">
                <i class="fa-solid fa-pen-to-square text-amber-400"></i>
                <span>تعديل ترخيص واشتراك العائلة</span>
            </h3>
            <button onclick="closeModal('editSubModal')" class="text-gray-400 hover:text-white transition">
                <i class="fa-solid fa-xmark text-lg"></i>
            </button>
        </div>

        <!-- Form -->
        <form id="editSubForm" onsubmit="handleEditSubSubmit(event)" class="p-5 space-y-4">
            <input type="hidden" id="editSubId">

            <div class="p-3 bg-gray-800/40 rounded-xl border border-gray-800 space-y-1">
                <div class="flex justify-between text-xs">
                    <span class="text-gray-400">العائلة:</span>
                    <span id="editSubFamilyName" class="text-white font-bold">-</span>
                </div>
                <div class="flex justify-between text-xs">
                    <span class="text-gray-400">ولي الأمر:</span>
                    <span id="editSubOwnerEmail" class="text-blue-400 font-mono">-</span>
                </div>
            </div>

            <div>
                <label class="block text-xs font-semibold text-gray-300 mb-1.5">باقة الترخيص (Subscription Tier)</label>
                <select id="editSubTierSelect" class="w-full px-3 py-2 text-xs bg-gray-800/80 border border-gray-700 rounded-xl text-white focus:border-amber-500 focus:outline-none">
                    <option value="free">Free (المجانية - جهاز واحد)</option>
                    <option value="basic">Basic (الأساسية - 3 أجهزة)</option>
                    <option value="premium">Premium (المتقدمة - 5 أجهزة)</option>
                    <option value="family_unlimited">Family Unlimited (غير محدودة - 99 جهاز)</option>
                </select>
            </div>

            <div>
                <label class="block text-xs font-semibold text-gray-300 mb-1.5">الحد الأقصى لأجهزة الأطفال المسموح بربطها</label>
                <input type="number" id="editSubMaxDevicesInput" required min="1" max="999" class="w-full px-3 py-2 text-xs bg-gray-800/80 border border-gray-700 rounded-xl text-white font-bold focus:border-amber-500 focus:outline-none">
            </div>

            <div>
                <label class="block text-xs font-semibold text-gray-300 mb-1.5">تاريخ انتهاء الصلاحية (اتركه فارغاً لترخيص دائم)</label>
                <input type="date" id="editSubExpiresAtInput" class="w-full px-3 py-2 text-xs bg-gray-800/80 border border-gray-700 rounded-xl text-white focus:border-amber-500 focus:outline-none">
                <!-- Quick extend pills -->
                <div class="flex gap-2 mt-2">
                    <button type="button" onclick="setQuickExpiry(30)" class="px-2 py-1 text-[11px] bg-gray-800 hover:bg-gray-700 text-gray-300 rounded-lg border border-gray-700">+ 30 يوم</button>
                    <button type="button" onclick="setQuickExpiry(90)" class="px-2 py-1 text-[11px] bg-gray-800 hover:bg-gray-700 text-gray-300 rounded-lg border border-gray-700">+ 3 أشهر</button>
                    <button type="button" onclick="setQuickExpiry(365)" class="px-2 py-1 text-[11px] bg-gray-800 hover:bg-gray-700 text-gray-300 rounded-lg border border-gray-700">+ سنة كاملة</button>
                    <button type="button" onclick="setQuickExpiry(0)" class="px-2 py-1 text-[11px] bg-gray-800 hover:bg-gray-700 text-amber-400 rounded-lg border border-gray-700">دائم</button>
                </div>
            </div>

            <div class="flex items-center gap-2 pt-2">
                <input type="checkbox" id="editSubIsActiveInput" checked class="rounded border-gray-700 text-emerald-500">
                <label for="editSubIsActiveInput" class="text-xs font-semibold text-emerald-400 cursor-pointer">الترخيص نشط ومفعل (إلغاء التحديد يجمد وصول العائلة)</label>
            </div>

            <!-- Footer Buttons -->
            <div class="flex items-center justify-end gap-3 pt-3 border-t border-gray-800">
                <button type="button" onclick="closeModal('editSubModal')" class="px-4 py-2 text-xs font-semibold bg-gray-800 hover:bg-gray-700 text-gray-300 rounded-xl transition">إلغاء</button>
                <button type="submit" class="px-5 py-2 text-xs font-bold bg-amber-600 hover:bg-amber-500 text-white rounded-xl transition shadow-lg shadow-amber-600/20">حفظ التغييرات</button>
            </div>
        </form>
    </div>
</div>
