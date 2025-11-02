@echo off

if not exist nul exit /b 0

del nul 2>nul && echo SUCCESS && exit /b 0
ren nul nul_backup 2>nul && del nul_backup 2>nul && echo SUCCESS && exit /b 0
del "\\?\%CD%\nul" 2>nul && echo SUCCESS && exit /b 0
powershell -NoProfile -Command "Remove-Item -LiteralPath '.\nul' -Force" 2>nul && echo SUCCESS && exit /b 0

echo FAILED
exit /b 1