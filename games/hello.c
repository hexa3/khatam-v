#include "khatam.h"

int speed = 3;

// an F so i can see if its mirrored
static const u8 letter[8] = {0x7e, 0x60, 0x60, 0x7c, 0x60, 0x60, 0x60, 0x00};

int main(void)
{
    // pattern 2, breathing on, pattern on
    GPU_PATTERN = INTERLACED | (1 << 4) | (1 << 5);

    bitmap(0, 300, 40, 3, RGB(3, 3, 3), letter);
    SND_VOICE0 = NOTE(440);   // A

    int x = 0;
    int sx = 100, sy = 100, dx = 3, dy = 2;
    while (1) {
        wait_vblank();

        GPU_SCROLLX = x;
        x += speed;

        // ui_in[0] and [1] move the star by hand
        if (buttons() & 1)
            sx -= 4;
        if (buttons() & 2)
            sx += 4;

        // turns red when it touches a line of the pattern
        u32 hit = COLLIDE;
        COLLIDE = 0;
        shape(0, sx, sy, 16, STAR, (hit & HIT_LINE(0)) ? RGB(3, 0, 0) : RGB(3, 3, 0));
        sx += dx;
        sy += dy;
        if (sx < 20 || sx > 620)
            dx = -dx;
        if (sy < 20 || sy > 460)
            dy = -dy;
    }
}
