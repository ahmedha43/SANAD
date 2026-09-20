<?php
/**
 * Admin Panel - Live Streaming & Security Logs Component
 */
declare(strict_types=1);
?>
<section id="tab-logs" class="hidden">
    <div class="rounded-2xl bg-gray-900/50 border border-gray-800 glass overflow-hidden">
        <div class="p-5 border-b border-gray-800/80 flex items-center justify-between">
            <div>
                <h3 class="font-bold text-white text-base">سجل البث والأمان المباشر (Live Security & Audit Logs)</h3>
                <p class="text-xs text-gray-500">مراقبة حية لكافة عمليات البث، الاقتران، حظر التطبيقات، وأوامر الإدارة الفورية</p>
            </div>
            <button onclick="clearLogs()" class="px-3 py-1 text-xs text-gray-400 hover:text-white bg-gray-800 border border-gray-700 rounded-lg transition">
                <i class="fa-solid fa-trash ml-1"></i> مسح السجل
            </button>
        </div>
        <div class="p-4">
            <div id="log-console" class="bg-black/80 rounded-xl p-4 font-mono text-xs text-gray-300 h-96 overflow-y-auto space-y-2 border border-gray-800">
                <div class="text-gray-500 font-mono py-8 text-center">
                    <i class="fa-solid fa-terminal text-2xl mb-2 block opacity-40"></i>
                    <span>بانتظار تدفق السجلات الأمنية المباشرة...</span>
                </div>
            </div>
        </div>
    </div>
</section>
