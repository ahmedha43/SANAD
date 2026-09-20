@echo off
chcp 65001 > nul
echo ==========================================================
echo   تشغيل لوحة الإدارة الرئيسية (Admin Panel PHP 8 Modular)
echo ==========================================================
echo جاري تشغيل الخادم المحلي على: http://localhost:3080
echo اضغط Ctrl+C لإيقاف الخادم في أي وقت.
echo.
php -S localhost:3080 -t admin-panel
