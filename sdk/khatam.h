// Khatam-V SDK - everything you need to talk to the hardware

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

#define SHAPE_X(n)     IO(0x40 + 16 * (n))
#define SHAPE_Y(n)     IO(0x44 + 16 * (n))
#define SHAPE_CTRL(n)  IO(0x48 + 16 * (n))

// patterns
#define STAR_CROSS  0
#define OCTAGONS    1
#define INTERLACED  2
#define DIAMONDS    3

// shapes
#define SQUARE      0
#define DIAMOND     1
#define STAR        2
#define OCTAGON     3

// colour from 0-3 per channel
#define RGB(r, g, b) (((r) << 4) | ((g) << 2) | (b))

static inline void shape(int n, int x, int y, int size, int kind, int colour)
{
    SHAPE_X(n) = x;
    SHAPE_Y(n) = y;
    SHAPE_CTRL(n) = size | (kind << 5) | (1 << 7) | (colour << 8);
}

static inline void shape_off(int n)
{
    SHAPE_CTRL(n) = 0;
}

#endif
