<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

Khatam-V is a small game console. There's a RISC-V CPU that runs C, a GPU that draws to VGA, and a sound chip, all in one design. The name comes from the khatam, the eight pointed star you see in islamic geometric patterns, and that's what the background of the screen is made of.

**CPU.** RV32E with the multiply instructions (Zmmul). It's multi-cycle and not pipelined at all, because the code runs straight out of SPI flash and a fetch takes ~70 clocks anyway, so a pipeline wouldn't buy anything. It's built to be small and to make timing on GF180 instead. No interrupts or traps, FENCE/ECALL/EBREAK/CSR do nothing.

**Memory.** Everything lives on the QSPI Pmod. Code and constants are in the flash, RAM is in the PSRAM. It talks plain 1-bit SPI at clk/2. To make fetch less slow, after a flash read CS stays low, and if the next read is the next address it just keeps clocking instead of sending the command and address again.

| Address     | What                          |
|-------------|-------------------------------|
| `0x0000000` | flash, 16 MB, read only, program starts at 0 |
| `0x1000000` | PSRAM, 8 MB                   |
| `0x2000000` | I/O (gpu, audio, buttons)     |

**Graphics.** 640x480 at 60 Hz, and there's no framebuffer, every pixel is worked out from (x, y) as the beam goes past. Back to front:

1. the background, one of 4 khatam star patterns. It can scroll, the stars can "breathe" (the radius goes in and out) and there's a shimmer on it
2. 4 shape sprites: square, diamond, star or octagon, up to 63 px
3. 2 bitmap sprites: 8x8, 1 bit, scaled 1x/2x/4x/8x

It also does collision detection in hardware, so a game can just read a register to see if a sprite hit a line of the pattern or another sprite.

**Sound.** 2 square wave voices and 1 noise voice, each with 4 bit volume, mixed into a PWM output on uio[7] (same pin as the TT audio Pmod). Note frequency is 25 MHz / 128 / period.

The full register list is at the top of `src/gpu.v`, `src/audio.v` and `src/project.v`, and `sdk/khatam.h` has C names for all of it.

## How to test

You need the flash on the QSPI Pmod to have a game in it. There's one in the repo, Starfall: catch the falling stars and dodge the red octagons.

1. Build it: `make` (needs clang + lld). That gives `build/starfall.bin`.
2. Write `build/starfall.bin` to the flash at address 0. While rst_n is low all the uio pins are inputs, so the RP2040 on the demo board can program the flash without the chip getting in the way.
3. Plug in the VGA Pmod and the QSPI Pmod (and the audio Pmod if you want sound), set the clock to 25 MHz (25.175 is also fine) and let go of reset.

You should see the star pattern. Press start (ui[2]) to play, ui[0] and ui[1] move left and right. Every 10 stars you go up a level, which changes the pattern and the colours and makes the stars faster. You get 3 lives.

To write your own game, copy `games/starfall.c` and `make GAME=mygame`.

## External hardware

- [TinyVGA Pmod](https://github.com/mole99/tiny-vga) on the outputs
- [QSPI Pmod](https://github.com/mole99/qspi-pmod) on the bidirectional pins (W25Q128 flash on CS0, APS6404 PSRAM on CS1)
- audio Pmod, or just a speaker/amp with a filter, on uio[7]
- buttons on ui[0]..ui[7], active high. Starfall only uses the first 3
