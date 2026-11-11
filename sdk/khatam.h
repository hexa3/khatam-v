// Khatam-V SDK

#ifndef KHATAM_H
#define KHATAM_H

typedef unsigned int   u32;
typedef unsigned short u16;
typedef unsigned char  u8;

#define IO(off) (*(volatile u32 *)(0x2000000 + (off)))

// ---------------- graphics ----------------
#define GPU_PATTERN    IO(0x00)
#define GPU_RADIUS     IO(0x04)
#define GPU_SCROLLX    IO(0x08)
#define GPU_SCROLLY    IO(0x0C)
#define GPU_PAL(n)     IO(0x10 + 4 * (n))

#define FRAME          IO(0xC0)
#define LINE           IO(0xC4)
#define BUTTONS        IO(0xD0)

#endif
