@echo off
title SPOC 技能 - 环境自检

echo.
echo ========================================
echo    SPOC 自动化技能 - 环境自检工具
echo ========================================
echo.
echo 这个工具会检查你的电脑是否已经准备好运行 SPOC 任务。
echo 检查过程中请不要关闭窗口。
echo.
echo ----------------------------------------
echo [检查 1/3] 查找 bsk 命令...
echo ----------------------------------------

set "BSK_PATH="
where bsk >nul 2>&1
if %errorlevel%==0 (
    set "BSK_PATH=bsk"
    echo   已找到！bsk 在系统 PATH 中。
) else (
    if exist "%USERPROFILE%\.local\bin\bsk.exe" (
        set "BSK_PATH=%USERPROFILE%\.local\bin\bsk.exe"
        echo   已找到！位置：%USERPROFILE%\.local\bin\
    ) else (
        echo   【未找到】
        echo.
        echo   你还没有安装 bsk 工具。
        echo   请先访问下面的地址，按说明安装：
        echo   https://github.com/Tencent/BrowserSkill
        echo.
        goto :end
    )
)

echo.
echo ----------------------------------------
echo [检查 2/3] 检查后台服务是否运行...
echo ----------------------------------------

set "BSK_AUTO_START=0"
"%BSK_PATH%" status --json >"%TEMP%\bsk_status.txt" 2>&1

findstr /C:"browser_name" "%TEMP%\bsk_status.txt" >nul 2>&1
if %errorlevel%==0 (
    echo   后台服务运行中，并且已连接浏览器。
) else (
    echo   【未连接】
    echo.
    echo   后台服务没有运行，或者浏览器扩展没有连上。
    echo   请在另一个命令行窗口执行下面的命令启动服务：
    echo.
    echo       bsk daemon start --foreground
    echo.
    echo   然后确认浏览器里已经装好 BrowserSkill 扩展并启用。
    echo.
    goto :end
)

echo.
echo ----------------------------------------
echo [检查 3/3] 检查技能文件是否完整...
echo ----------------------------------------

set "SKILLDIR=%~dp0.."
if exist "%SKILLDIR%\SKILL.md" (
    echo   技能主文件 SKILL.md 存在。
) else (
    echo   【缺失】找不到 SKILL.md，请确认解压位置是否正确。
    goto :end
)

if exist "%SKILLDIR%\scripts\run_doc.sh" (
    echo   脚本文件存在。
) else (
    echo   【缺失】找不到 scripts 目录下的脚本。
    goto :end
)

echo.
echo ========================================
echo    检查完成！环境已经完全就绪。
echo ========================================
echo.
echo 接下来你可以：
echo   1. 打开浏览器，登录 https://study.nju.edu.cn
echo   2. 进入你的课程页面
echo   3. 在 Agent 里说：「帮我完成这门课的所有任务点」
echo.
echo 详细步骤请阅读：从零开始配置教程.txt
echo.

:end
echo.
pause
