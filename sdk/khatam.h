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

static inline void background(int pattern, int cell, int breathe)
{
    GPU_PATTERN = pattern | (cell << 2) | (breathe << 4) | (1 << 5);
}

static inline void wait_vblank(void)
{
    u32 f = FRAME;
    while (FRAME == f)
        ;
}

static inline u32 buttons(void)
{
    return BUTTONS;
}

#endif
