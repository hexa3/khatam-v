# build hello for the chip

CC      = clang
LD      = ld.lld
OBJCOPY = llvm-objcopy

CFLAGS = --target=riscv32-unknown-elf -march=rv32e -mabi=ilp32e -Os -ffreestanding -nostdlib -mno-relax -Wall -Isdk

all: build/hello.bin

build/hello.o: games/hello.c sdk/khatam.h
	mkdir -p build
	$(CC) $(CFLAGS) -c $< -o $@

build/crt0.o: sdk/crt0.S
	mkdir -p build
	$(CC) $(CFLAGS) -c $< -o $@

build/hello.elf: build/crt0.o build/hello.o sdk/link.ld
	$(LD) -T sdk/link.ld build/crt0.o build/hello.o -o $@

build/hello.bin: build/hello.elf
	$(OBJCOPY) -O binary $< $@

clean:
	rm -rf build

.PHONY: all clean
