@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SaveChatExpMeter.ps1" -AskDeleteChat
pause
