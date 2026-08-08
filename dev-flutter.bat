@echo off
echo BEFORE-PATH
set "PATH=D:\DevTools\Git\cmd;D:\DevTools\Git\mingw64\bin;D:\DevTools\Git\usr\bin;D:\DevTools\flutter\bin;%PATH%"
echo AFTER-PATH
cd /d D:\DevTools\flutter
echo AFTER-CD
call bin\flutter.bat --version
echo AFTER-FLUTTER
