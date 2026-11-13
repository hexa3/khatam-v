// bits of libgcc the compiler expects

#include "khatam.h"

// the cpu has a hardware multiply but no divide, so divide is done here
u32 __udivsi3(u32 n, u32 d)
{
    u32 q = 0, r = 0;
    for (int i = 31; i >= 0; i--) {
        r = (r << 1) | ((n >> i) & 1);
        if (r >= d) {
            r -= d;
            q |= 1u << i;
        }
    }
    return q;
}

u32 __umodsi3(u32 n, u32 d)
{
    return n - __udivsi3(n, d) * d;
}

int __divsi3(int n, int d)
{
    int neg = (n < 0) != (d < 0);
    u32 q = __udivsi3(n < 0 ? -n : n, d < 0 ? -d : d);
    return neg ? -(int)q : (int)q;
}

int __modsi3(int n, int d)
{
    return n - __divsi3(n, d) * d;
}

// no_builtin stops clang "optimising" these into calls to themselves
__attribute__((no_builtin)) void *memset(void *dst, int c, u32 n)
{
    u8 *p = dst;
    while (n--)
        *p++ = c;
    return dst;
}

__attribute__((no_builtin)) void *memcpy(void *dst, const void *src, u32 n)
{
    u8 *d = dst;
    const u8 *s = src;
    while (n--)
        *d++ = *s++;
    return dst;
}

void sound_off(void)
{
    SND_VOLUME = 0;
}

// xorshift, seeded from the frame counter + beam position the first time
static u32 seed;

u32 random(void)
{
    if (seed == 0)
        seed = (FRAME << 10) ^ LINE ^ 0x5eed;
    seed ^= seed << 13;
    seed ^= seed >> 17;
    seed ^= seed << 5;
    return seed;
}
