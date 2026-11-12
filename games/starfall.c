// Starfall - catch the falling stars, dodge the red octagons

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
    int x, y, speed, kind;  // kind 0 = star (good), 1 = bomb
};

static struct faller stuff[4];
static int px = 304;
static int n, lives = 3;

static u32 seed = 12345;

static u32 random(void)
{
    seed ^= seed << 13;
    seed ^= seed >> 17;
    seed ^= seed << 5;
    return seed;
}

static void new_faller(int i)
{
    stuff[i].x = 40 + random() % 560;
    stuff[i].y = 0;
    stuff[i].speed = 2 + random() % 3;
    stuff[i].kind = (random() % 4 == 0);   // 1 in 4 is a bomb
}

static void draw_faller(int i)
{
    if (stuff[i].kind)
        shape(i, stuff[i].x, stuff[i].y, 12, OCTAGON, RGB(3, 0, 0));
    else
        shape(i, stuff[i].x, stuff[i].y, 16, STAR, 0x3c);
}

int main(void)
{
    background(0, 0, 0);   // no breathing for now, so the radius test shows
    for (int i = 0; i < 4; i++) {
        new_faller(i);
        stuff[i].y = -(i * 120);   // spread them out at the start
    }

    while (1) {
        wait_vblank();
        u32 frame = FRAME;

        // collisions from last frame
        u32 hits = COLLIDE;
        COLLIDE = 0;

        if (hits & HIT_SPRITE(4)) {
            for (int i = 0; i < 4; i++) {
                if (!(hits & HIT_SPRITE(i)) || stuff[i].y < 380)
                    continue;
                if (stuff[i].kind)
                    lives--;
                else
                    n++;
                new_faller(i);
            }
        }
        GPU_RADIUS = 8 + n;   // testing, star gets bigger every catch

        if (lives == 0) {
            // TODO game over screen
            while (1)
                ;
        }

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
                new_faller(i);
            if (stuff[i].y >= 0)
                draw_faller(i);
            else
                shape_off(i);
        }

        // slowly drift the background
        GPU_SCROLLX = frame >> 1;
    }
}
