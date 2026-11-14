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

#define SND_VOICE0     IO(0xE0)
#define SND_VOICE1     IO(0xE4)
#define SND_NOISE      IO(0xE8)
#define SND_VOLUME     IO(0xEC)

#define FRAME          IO(0xC0)
#define LINE           IO(0xC4)
#define COLLIDE        IO(0xC8)
#define BUTTONS        IO(0xD0)

#define BITMAP_X(n)    IO(0x80 + 32 * (n))
#define BITMAP_Y(n)    IO(0x84 + 32 * (n))
#define BITMAP_CTRL(n) IO(0x88 + 32 * (n))
#define BITMAP_LO(n)   IO(0x8C + 32 * (n))
#define BITMAP_HI(n)   IO(0x90 + 32 * (n))

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

// collision bits
#define HIT_LINE(n)   (1u << (n))        // sprite n touched a pattern line
#define HIT_SPRITE(n) (1u << (6 + (n)))  // sprite n touched another sprite
// sprite numbers for those: shapes are 0-3, bitmaps are 4 and 5

// note period for the sound registers (freq in Hz)
#define NOTE(hz) (25000000 / 128 / (hz))

// palette slots
#define PAL_BG      0
#define PAL_FILL    1
#define PAL_FILL2   2
#define PAL_LINE    3
#define PAL_ACCENT  4

// colour from 0-3 per channel
#define RGB(r, g, b) (((r) << 4) | ((g) << 2) | (b))

static inline void background(int pattern, int cell, int breathe)
{
    GPU_PATTERN = pattern | (cell << 2) | (breathe << 4) | (1 << 5);
}

static inline void plain_background(int colour)
{
    GPU_PAL(PAL_BG) = colour;
    GPU_PATTERN = 0;
}

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

static inline void bitmap(int n, int x, int y, int scale, int colour, const u8 *rows)
{
    BITMAP_X(n) = x;
    BITMAP_Y(n) = y;
    BITMAP_LO(n) = rows[0] | (rows[1] << 8) | (rows[2] << 16) | (rows[3] << 24);
    BITMAP_HI(n) = rows[4] | (rows[5] << 8) | (rows[6] << 16) | (rows[7] << 24);
    BITMAP_CTRL(n) = scale | (1 << 7) | (colour << 8);
}

static inline void bitmap_move(int n, int x, int y)
{
    BITMAP_X(n) = x;
    BITMAP_Y(n) = y;
}

static inline void bitmap_off(int n)
{
    BITMAP_CTRL(n) = 0;
}

static inline u32 buttons(void)
{
    return BUTTONS;
}

static inline void wait_vblank(void)
{
    u32 f = FRAME;
    while (FRAME == f)
        ;
}

void sound_off(void);
u32  random(void);

#endif
