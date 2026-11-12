# build a game into a flash image
#   make                -> build/hello.bin (write this to the flash at address 0)
#   make GAME=mygame    -> games/mygame.c

GAME ?= hello

CC      = clang
LD      = ld.lld
OBJCOPY = llvm-objcopy

CFLAGS = --target=riscv32-unknown-elf -march=rv32e -mabi=ilp32e -Os -ffreestanding -nostdlib -mno-relax -Wall -Isdk

all: build/$(GAME).bin build/$(GAME).hex

build/%.o: games/%.c sdk/khatam.h
	mkdir -p build
	$(CC) $(CFLAGS) -c $< -o $@

build/crt0.o: sdk/crt0.S
	mkdir -p build
	$(CC) $(CFLAGS) -c $< -o $@

build/$(GAME).elf: build/crt0.o build/$(GAME).o sdk/link.ld
	$(LD) -T sdk/link.ld build/crt0.o build/$(GAME).o -o $@

build/$(GAME).bin: build/$(GAME).elf
	$(OBJCOPY) -O binary $< $@

# one byte per line, for $$readmemh in the FPGA build
build/$(GAME).hex: build/$(GAME).bin
	od -An -tx1 -v $< | tr -s ' ' '\n' | sed '/^$$/d' > $@

clean:
	rm -rf build

.PHONY: all clean
