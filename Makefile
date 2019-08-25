AS := rgbasm
ASFLAGS := -i inc/ -i data/ -o
LD := rgblink
LDFLAGS1 := -d -o
LDFLAGS2 := -o
FX := rgbfix
FXFLAGS1 := -p 0 -r 0 -t DMG_EXAMPLE -v
FXFLAGS2 := -C -p 0 -r 0 -t CGB_EXAMPLE -v

dmg_src := $(wildcard dmg/*.asm)
cgb_src := $(wildcard cgb/*.asm)
dmg_rom := $(dmg_src:.asm=.gb)
cgb_rom := $(cgb_src:.asm=.gbc)

all:    $(dmg_rom) $(cgb_rom)

%.gb: %.o
        $(LD) $(LDFLAGS1) $@ $<
        $(FX) $(FXFLAGS1) $@

%.gbc: %.o
        $(LD) $(LDFLAGS2) $@ $<
        $(FX) $(FXFLAGS2) $@

%.o: %.asm
        $(AS) $(ASFLAGS) $@ $<

clean:
        rm -f dmg/*.o
        rm -f dmg/*.gb
        rm -f cgb/*.o
        rm -f cgb/*.gbc
