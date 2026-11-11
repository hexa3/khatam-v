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
