@echo off
chcp 936 >nul
title bsk 工具 · 本地离线安装
echo.
echo ==========================================
echo   bsk 工具 · 本地离线安装
echo ==========================================
echo.
echo  即将开始安装。如果弹出权限提示，请点「是」。
echo.
pause

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0本地安装.ps1"

echo.
echo ==========================================
echo  脚本执行结束。按任意键关闭窗口。
echo ==========================================
pause >nul
