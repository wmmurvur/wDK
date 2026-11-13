@echo off
rem Cift tiklayin: site bu bilgisayarda acilir ve tarayici kendiliginden gelir. Kapatmak icin bu pencereyi kapatin.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_yerel-sunucu\sunucu.ps1"
pause
