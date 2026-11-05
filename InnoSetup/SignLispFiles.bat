@ECHO OFF
REM Autodesk AcSignTool for sample .lsp files.
REM /cert: serial is the MANUSOFT SSL.com cert on YubiKey (same as SuperPurge).
REM Old Sectigo serial 00aaf126b0b0905a7de59b333e5f77b505 is not used.
REM AcSignTool uses the Windows store, so enter the YubiKey PIV PIN when prompted.
SETLOCAL
CD /D "%~dp0"
SET "ACSIGN=P:\Tools\Lisp\acsigntool"
IF NOT EXIST "%ACSIGN%.exe" SET "ACSIGN=T:\Lisp\AcSignTool"
IF DEFINED LSPLOAD_LISP_SIGN_CERT_SERIAL (
  SET "CERT=%LSPLOAD_LISP_SIGN_CERT_SERIAL%"
) ELSE IF DEFINED SUPERPURGE_LISP_SIGN_CERT_SERIAL (
  SET "CERT=%SUPERPURGE_LISP_SIGN_CERT_SERIAL%"
) ELSE (
  SET "CERT=638d6e8de754b9d80b22d5b5a01eae31"
)

"%ACSIGN%" -remove -force /file:MyLispPlugin.lsp
IF ERRORLEVEL 1 EXIT /B 1
"%ACSIGN%" -sign /file:MyLispPlugin.lsp /cert:%CERT% /time:2 /comment:LspLoad
IF ERRORLEVEL 1 EXIT /B 1
"%ACSIGN%" -remove -force /file:MyLispPluginCmds.lsp
IF ERRORLEVEL 1 EXIT /B 1
"%ACSIGN%" -sign /file:MyLispPluginCmds.lsp /cert:%CERT% /time:2 /comment:LspLoad
IF ERRORLEVEL 1 EXIT /B 1
