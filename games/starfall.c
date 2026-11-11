// Starfall - catch the falling stars

#include "khatam.h"

struct faller {
    int x, y, speed;
};

static struct faller stuff[3];
static int px = 304;

static u32 seed = 12345;

static u32 random(void)
{
    seed ^= seed << 13;
    seed ^= seed >> 17;
    seed ^= seed << 5;
    return seed;
}

static void new_star(int i)
{
    stuff[i].x = 40 + random() % 560;
    stuff[i].y = 0;
    stuff[i].speed = 2 + random() % 3;
}

int main(void)
{
    background(0, 0, 1);
    for (int i = 0; i < 3; i++) {
        new_star(i);
        stuff[i].y = -(i * 120);   // spread them out at the start
    }

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

        // move the stars (shape 0 is the player so they use 1-3)
        for (int i = 0; i < 3; i++) {
            stuff[i].y += stuff[i].speed;
            if (stuff[i].y > 496)
                new_star(i);
            if (stuff[i].y >= 0)
                shape(i + 1, stuff[i].x, stuff[i].y, 16, STAR, 0x3c);
            else
                shape_off(i + 1);
        }

        // slowly drift the background
        GPU_SCROLLX = frame >> 1;
    }
}
