# build starfall into a flash image
# needs clang + lld

CC      = clang
LD      = ld.lld
OBJCOPY = llvm-objcopy

CFLAGS = --target=riscv32-unknown-elf -march=rv32e_zmmul -mabi=ilp32e \
         -Os -ffreestanding -nostdlib -Isdk

all: build/starfall.bin

build/starfall.o: games/starfall.c sdk/khatam.h
	$(CC) $(CFLAGS) -c games/starfall.c -o build/starfall.o

build/crt0.o: sdk/crt0.S
	$(CC) $(CFLAGS) -c sdk/crt0.S -o build/crt0.o

build/starfall.elf: build/crt0.o build/starfall.o sdk/link.ld
	$(LD) -T sdk/link.ld build/crt0.o build/starfall.o -o build/starfall.elf

build/starfall.bin: build/starfall.elf
	$(OBJCOPY) -O binary build/starfall.elf build/starfall.bin

clean:
	rm -rf build

.PHONY: all clean
