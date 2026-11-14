// bits of libc / libgcc the compiler expects

#include "khatam.h"

// the cpu has no divide, so divide is done here
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

// ...and no multiply either (yet)
u32 __mulsi3(u32 a, u32 b)
{
    u32 r = 0;
    while (b) {
        if (b & 1)
            r += a;
        a <<= 1;
        b >>= 1;
    }
    return r;
}
