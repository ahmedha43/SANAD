@echo off
chcp 65001 >nul
title سَنَد - حماية ورعاية الكمبيوتر (SANAD Windows Agent)
echo ========================================================
echo   تشغيل تطبيق سَنَد لحماية ورعاية الكمبيوتر (Windows Agent)
echo ========================================================
cd /d "%~dp0\windows-agent\src\Sanad.UI"
dotnet run --no-build
pause
