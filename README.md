# hello 8-bit world!
Example of Gameboy (DMG) "Hello world!" written in assembly language. Use with [RGBASM](https://github.com/rednex/rgbds).

```
rgbasm -ohello.o hello.s
rgblink -p00 -ohello.gb hello.o
rgbfix -v -m00 -p00 -tHello hello.gb 
```
