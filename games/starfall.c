// Starfall - catch the falling stars
//
// buttons: ui_in[0] = left, ui_in[1] = right

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

static int fall_x[4], fall_y[4], fall_speed[4];
static int caught;

// my own random for now
static u32 seed;

static u32 random(void)
{
    // seeded from the frame counter + beam position the first time
    if (seed == 0)
        seed = (FRAME << 10) ^ LINE ^ 0x5eed;
    seed ^= seed << 13;
    seed ^= seed >> 17;
    seed ^= seed << 5;
    return seed;
}

static void new_star(int i)
{
    fall_x[i] = 40 + random() % 560;
    fall_y[i] = 0;
    fall_speed[i] = 1 + random() % 3;
}

int main(void)
{
    GPU_PATTERN = STAR_CROSS | (1 << 4) | (1 << 5);

    int player_x = 304;
    bitmap(0, player_x, 420, 2, RGB(3, 2, 0), lantern);

    for (int i = 0; i < 4; i++) {
        new_star(i);
        fall_y[i] = -(i * 120);
    }

    while (1) {
        wait_vblank();

        // collisions from last frame
        u32 hits = COLLIDE;
        COLLIDE = 0;
        GPU_PAL(0) = hits ? RGB(3, 0, 0) : RGB(3, 3, 3);   // debug: flash when something hits

        if (hits & HIT_SPRITE(4)) {
            for (int i = 0; i < 4; i++) {
                if (hits & HIT_SPRITE(i)) {
                    caught++;
                    new_star(i);
                }
            }
        }

        u32 b = buttons();
        if ((b & 1) && player_x > 4)
            player_x -= 6;
        if ((b & 2) && player_x < 604)
            player_x += 6;
        BITMAP_X(0) = player_x;

        for (int i = 0; i < 4; i++) {
            fall_y[i] += fall_speed[i];
            if (fall_y[i] > 480 + 16)
                new_star(i);
            if (fall_y[i] >= 0)
                shape(i, fall_x[i], fall_y[i], 16, STAR, RGB(3, 3, 0));
            else
                shape_off(i);
        }
    }
}
