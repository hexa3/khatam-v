# build a game into a flash image
#   make                -> build/starfall.bin (write this to the flash at address 0)
#   make GAME=mygame    -> games/mygame.c
#
# needs clang + lld (arch: pacman -S clang lld llvm)

GAME ?= starfall

CC      = clang
LD      = ld.lld
OBJCOPY = llvm-objcopy

CFLAGS = --target=riscv32-unknown-elf -march=rv32e_zmmul -mabi=ilp32e \
         -Os -ffreestanding -fno-builtin -nostdlib -mno-relax -Wall -Isdk

all: build/$(GAME).bin build/$(GAME).hex

build/%.o: games/%.c sdk/khatam.h | build
	$(CC) $(CFLAGS) -c $< -o $@

build/sdk.o: sdk/khatam.c sdk/khatam.h | build
	$(CC) $(CFLAGS) -c $< -o $@

build/crt0.o: sdk/crt0.S | build
	$(CC) $(CFLAGS) -c $< -o $@

build/$(GAME).elf: build/crt0.o build/$(GAME).o build/sdk.o sdk/link.ld
	$(LD) -T sdk/link.ld build/crt0.o build/$(GAME).o build/sdk.o -o $@

build/$(GAME).bin: build/$(GAME).elf
	$(OBJCOPY) -O binary $< $@
	@echo "$@: $$(wc -c < $@) bytes"

# one byte per line, for $$readmemh in the FPGA build
build/$(GAME).hex: build/$(GAME).bin
	od -An -tx1 -v $< | tr -s ' ' '\n' | sed '/^$$/d' > $@

build:
	mkdir -p build

clean:
	rm -rf build

.PHONY: all clean
