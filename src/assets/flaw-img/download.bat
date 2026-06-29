@echo off
chcp 65001 >nul
set "IMG_BASE=http://192.168.2.57"
set "OUT_DIR=%~dp0"

echo 开始下载缺陷图片...
echo.

set "IMAGES=/2026-06-23/20260623222923432.jpg /2026-06-23/20260623224807359.jpg /2026-06-28/20260628150733159.jpg /2026-06-29/20260629013429400.jpg"

for %%i in (%IMAGES%) do (
    for %%f in (%%i) do set "filename=%%~nxi"
    echo 下载: %IMG_BASE%%%i
    curl -o "%OUT_DIR%%%~nxi" "%IMG_BASE%%%i" --connect-timeout 30 --max-time 60
    if exist "%OUT_DIR%%%~nxi" (
        echo   [成功] %%~nxi
    ) else (
        echo   [失败] 服务器不可达
    )
    echo.
)

echo 完成！
pause
