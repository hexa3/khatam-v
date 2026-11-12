// Starfall - catch the falling stars

#include "khatam.h"

static const u8 lantern[8] = {
    0x18, // ...##...
    0x3c, // ..####..
    0x7e, // .######.
    0xdb, // ##.##.##
    0xff, // ########
    0x7e, // .######.
    0x3c, // ..####..
    0x18, // ...##...
};

struct faller {
    int x, y, speed;
};

static struct faller stuff[4];
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
    for (int i = 0; i < 4; i++) {
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
        bitmap(0, px, 420, 2, 0x38, lantern);

        // move the stars
        for (int i = 0; i < 4; i++) {
            stuff[i].y += stuff[i].speed;
            if (stuff[i].y > 496)
                new_star(i);
            if (stuff[i].y >= 0)
                shape(i, stuff[i].x, stuff[i].y, 16, STAR, 0x3c);
            else
                shape_off(i);
        }

        // slowly drift the background
        GPU_SCROLLX = frame >> 1;
    }
}
