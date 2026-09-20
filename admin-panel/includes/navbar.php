<?php
/**
 * Admin Panel - Top Header Navbar Component
 */
declare(strict_types=1);
?>
<header class="h-16 border-b border-gray-800 bg-gray-900/50 flex items-center justify-between px-8 sticky top-0 z-10 glass">
    <div class="flex items-center gap-4">
        <h2 id="page-title" class="font-bold text-lg text-white">لوحة القيادة والمراقبة الحية</h2>
        <span class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
            <span class="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
            نظام متصل ومباشر
        </span>
    </div>

    <div class="flex items-center gap-3">
        <!-- Link to Parent Dashboard -->
        <a href="/dashboard/" target="_blank" class="px-3 py-1.5 text-xs font-semibold bg-blue-600/20 text-blue-400 border border-blue-500/30 rounded-lg hover:bg-blue-600/30 transition flex items-center gap-1.5">
            <i class="fa-solid fa-arrow-up-right-from-square"></i>
            <span>لوحة ولي الأمر (Web App)</span>
        </a>

        <!-- Refresh Button -->
        <button onclick="refreshData()" class="p-2 text-gray-400 hover:text-white bg-gray-800/60 border border-gray-700/60 rounded-lg transition" title="تحديث البيانات فورياً">
            <i id="refresh-icon" class="fa-solid fa-rotate w-4 h-4 flex items-center justify-center"></i>
        </button>

        <!-- RTL/LTR Toggle -->
        <button onclick="toggleLang()" class="px-3 py-1.5 text-xs font-medium text-gray-400 hover:text-white bg-gray-800/60 border border-gray-700/60 rounded-lg transition">
            AR / EN
        </button>
    </div>
</header>
