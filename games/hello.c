#include "khatam.h"

int speed = 3;

int main(void)
{
    // pattern 2, breathing on, pattern on
    GPU_PATTERN = INTERLACED | (1 << 4) | (1 << 5);

    int x = 0;
    while (1) {
        GPU_SCROLLX = x;
        x += speed;
        for (volatile int i = 0; i < 20000; i++)
            ;
    }
}
