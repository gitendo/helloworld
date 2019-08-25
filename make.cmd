@REM RGBDS Makefile for Windows, written by tmk - https://github.com/gitendo

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
	rgbfix -p 0 -r 0 -t DMG_EXAMPLE -v %%~ni.gb
	@IF ERRORLEVEL 1 (
		ECHO Failed to fix %%~ni.gb
		GOTO :eof
	)
)

@CD ../cgb
@FOR /F "delims==" %%i in ('dir /b /on *.asm') DO @(
	rgbasm -i ..\inc\ -i ..\data\ -o %%~ni.o %%i
	@IF ERRORLEVEL 1 (
		ECHO Failed to assemble %%~i 
		GOTO :eof
	)
	rgblink -o %%~ni.gbc %%~ni.o
	@IF ERRORLEVEL 1 (
		ECHO Failed to link %%~ni.o
		GOTO :eof
	)
	@DEL %%~ni.o
	rgbfix -C -p 0 -r 0 -t CGB_EXAMPLE -v %%~ni.gbc
	@IF ERRORLEVEL 1 (
		ECHO Failed to fix %%~ni.gbc
		GOTO :eof
	)
)


@ECHO Build successful!