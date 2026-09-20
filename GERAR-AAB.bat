@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ============================================================
echo  CALM CUP - gerar AAB de release para a Play Store
echo ============================================================
echo.

REM O compilador AOT do Android (gen_snapshot) nao consegue ler arquivos em
REM caminho com acento: o "A" de "Area de Trabalho" chega corrompido e o build
REM morre com "Unable to read file: ...app.dill" / "exited with code 255".
REM flutter test, analyze, build web e o modo debug funcionam normalmente --
REM so o AOT quebra, o que torna o erro confuso. Por isso a checagem vem antes.
REM A checagem vai pelo PowerShell porque findstr nao detecta o acento de
REM forma confiavel sob a codepage UTF-8 ligada acima (testado: passava direto).
set "CAMINHO_OK=SIM"
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "if ((Get-Location).Path -cmatch '[^\x20-\x7E]') { 'NAO' } else { 'SIM' }"`) do set "CAMINHO_OK=%%i"
if /i "%CAMINHO_OK%"=="NAO" (
    echo  ERRO: esta pasta tem caractere acentuado no caminho.
    echo.
    echo    %CD%
    echo.
    echo  O build de release vai falhar com "Unable to read file: app.dill".
    echo  Rode a partir do clone sem acento, por exemplo:
    echo.
    echo    C:\projetos\calmcup-release
    echo.
    echo  Para recriar esse clone, veja a secao "Gerando um release"
    echo  no README.md.
    echo.
    pause
    exit /b 1
)

"C:\flutter\bin\flutter.bat" build appbundle --release
if errorlevel 1 (
    echo.
    echo  O build FALHOU. Nada foi gerado.
    pause
    exit /b 1
)

echo.
echo ------------------------------------------------------------
echo  AAB gerado em:
echo   %CD%\build\app\outputs\bundle\release\app-release.aab
echo  Suba ESTE arquivo no Google Play Console.
echo ------------------------------------------------------------
start "" explorer "%CD%\build\app\outputs\bundle\release"
echo.
pause
