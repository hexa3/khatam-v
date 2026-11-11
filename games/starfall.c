// Starfall - catch the falling stars

#include "khatam.h"

static int px = 304;

int main(void)
{
    background(0, 0, 1);

    while (1) {
        wait_vblank();
        u32 frame = FRAME;

        // move the player
        u32 b = buttons();
        if ((b & 1) && px > 4)
            px -= 6;
        if ((b & 2) && px < 640)
            px += 6;
        shape(0, px, 420, 16, SQUARE, 0x38);

        // slowly drift the background
        GPU_SCROLLX = frame >> 1;
    }
}
