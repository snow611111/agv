@echo off
cd /d "%~dp0"

echo Starting RTSP relay server...
taskkill /f /im python3.exe >nul 2>&1
taskkill /f /im ffmpeg.exe >nul 2>&1
timeout /t 2 /nobreak >nul

start "RTSP_Relay" /min python3 rtsp_server.py
echo RTSP relay server started on port 8088
