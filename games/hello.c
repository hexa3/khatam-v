#include "khatam.h"

int speed = 3;

int main(void)
{
    // pattern 2, breathing on, pattern on
    GPU_PATTERN = INTERLACED | (1 << 4) | (1 << 5);

    int x = 0;
    int sx = 100, sy = 100, dx = 3, dy = 2;
    while (1) {
        GPU_SCROLLX = x;
        x += speed;

        shape(0, sx, sy, 16, STAR, RGB(3, 3, 0));
        sx += dx;
        sy += dy;
        if (sx < 20 || sx > 620)
            dx = -dx;
        if (sy < 20 || sy > 460)
            dy = -dy;

        for (volatile int i = 0; i < 20000; i++)
            ;
    }
}
