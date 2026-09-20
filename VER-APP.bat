@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ============================================================
echo  CALM CUP - rodar o app (debug) para ver funcionando
echo ============================================================
echo.
echo Abra um emulador no Android Studio ou conecte o celular,
echo depois aguarde o build. Pressione 'q' para sair.
echo.
REM O modo debug usa JIT, nao o gen_snapshot, entao roda normalmente mesmo
REM em caminho com acento -- ao contrario do GERAR-AAB.bat.
"C:\flutter\bin\flutter.bat" run
echo.
pause
