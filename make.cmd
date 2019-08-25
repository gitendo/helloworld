@REM
@CD dmg
@FOR /F "delims==" %%i in ('dir /b /on *.asm') DO @(
	rgbasm -i ..\inc\ -i ..\data\ -o %%~ni.o %%i
	@IF ERRORLEVEL 1 (
		ECHO Failed to assemble %%~i 
		GOTO :eof
	)
	rgblink -d -o %%~ni.gb %%~ni.o
	@IF ERRORLEVEL 1 (
		ECHO Failed to link %%~ni.o
		GOTO :eof
	)
	@DEL %%~ni.o
	rgbfix -p 0 -r 0 -v %%~ni.gb
	@IF ERRORLEVEL 1 (
		ECHO Failed to fix %%~ni.gb
		GOTO :eof
	)
)
@ECHO Build successful!