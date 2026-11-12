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

void sound_off(void)
{
    SND_VOLUME = 0;
}
