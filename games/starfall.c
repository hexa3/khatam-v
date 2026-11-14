// Starfall - catch the falling stars
//
// buttons: ui_in[0] = left, ui_in[1] = right, ui_in[2] = start

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

static struct faller fall[4];
static int player_x;
static int caught, lives;

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

static void new_faller(int i)
{
    fall[i].x = 40 + random() % 560;
    fall[i].y = 0;
    fall[i].speed = 1 + random() % 3;
    fall[i].kind = (random() % 4 == 0);   // 1 in 4 is a bomb
}

static void draw_faller(int i)
{
    if (fall[i].kind)
        shape(i, fall[i].x, fall[i].y, 12, OCTAGON, RGB(3, 0, 0));
    else
        shape(i, fall[i].x, fall[i].y, 16, STAR, RGB(3, 3, 0));
}

static void new_game(void)
{
    player_x = 304;
    caught = 0;
    lives = 3;
    GPU_PATTERN = STAR_CROSS | (1 << 4) | (1 << 5);
    bitmap(0, player_x, 420, 2, RGB(3, 2, 0), lantern);
    for (int i = 0; i < 4; i++) {
        new_faller(i);
        fall[i].y = -(i * 120);   // spread them out at the start
    }
}

static void game_over(void)
{
    SND_VOLUME = 0;
    for (int i = 0; i < 4; i++)
        shape_off(i);
    bitmap_off(0);

    // red background until start is pressed
    plain_background(RGB(2, 0, 0));
    while (!(buttons() & 4))
        wait_vblank();
}

int main(void)
{
    new_game();

    while (1) {
        wait_vblank();

        // collisions from last frame
        u32 hits = COLLIDE;
        COLLIDE = 0;
        GPU_PAL(0) = hits ? RGB(3, 0, 0) : RGB(3, 3, 3);   // debug: flash when something hits

        if (hits & HIT_SPRITE(4)) {
            for (int i = 0; i < 4; i++) {
                // stars that touch each other count as a hit too, so only look near the bottom
                if (!(hits & HIT_SPRITE(i)) || fall[i].y < 420 - 40)
                    continue;
                if (fall[i].kind)
                    lives--;
                else
                    caught++;
                new_faller(i);
            }
        }

        if (lives == 0) {
            game_over();
            new_game();
            continue;
        }

        u32 b = buttons();
        if ((b & 1) && player_x > 4)
            player_x -= 6;
        if ((b & 2) && player_x < 604)
            player_x += 6;
        BITMAP_X(0) = player_x;

        for (int i = 0; i < 4; i++) {
            fall[i].y += fall[i].speed;
            if (fall[i].y > 480 + 16)
                new_faller(i);
            if (fall[i].y >= 0)
                draw_faller(i);
            else
                shape_off(i);
        }
    }
}
