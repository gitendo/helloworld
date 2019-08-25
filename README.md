# Hello Game Boy!
This repo started as simple "Hello world!" for Gameboy (DMG) written in assembly language. Few stars later I thought I could start adding some other examples as well, including Game Boy Color (CGB). So here it is - new folder structure, makefiles for Windows / Linux and content that will gradually follow. Everything commented and ready to assemble and link with [RGBASM](https://github.com/rednex/rgbds). 

On Windows make sure RGBDS binaries are added to path - here's [how to](https://www.computerhope.com/issues/ch000549.htm) in case you don't know. Otherwise you'd need to change path to files being included and use these commands for each source file:

```
rgbasm.exe -o hello.o hello.s
rgblink.exe -d -o hello.gb hello.o
rgbfix.exe -p 0 -r 0 -v hello.gb 
```
