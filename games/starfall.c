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

static const u8 digits[10][8] = {
    {0x3c, 0x66, 0x6e, 0x76, 0x66, 0x66, 0x3c, 0x00}, // 0
    {0x18, 0x38, 0x18, 0x18, 0x18, 0x18, 0x7e, 0x00}, // 1
    {0x3c, 0x66, 0x06, 0x0c, 0x30, 0x60, 0x7e, 0x00}, // 2
    {0x3c, 0x66, 0x06, 0x1c, 0x06, 0x66, 0x3c, 0x00}, // 3
    {0x0c, 0x1c, 0x3c, 0x6c, 0x7e, 0x0c, 0x0c, 0x00}, // 4
    {0x7e, 0x60, 0x7c, 0x06, 0x06, 0x66, 0x3c, 0x00}, // 5
    {0x3c, 0x60, 0x7c, 0x66, 0x66, 0x66, 0x3c, 0x00}, // 6
    {0x7e, 0x06, 0x0c, 0x18, 0x30, 0x30, 0x30, 0x00}, // 7
    {0x3c, 0x66, 0x66, 0x3c, 0x66, 0x66, 0x3c, 0x00}, // 8
    {0x3c, 0x66, 0x66, 0x3e, 0x06, 0x0c, 0x38, 0x00}, // 9
};

// one colour scheme per level: bg, fill, fill2, line, accent
static const u8 themes[4][5] = {
    {RGB(3,3,3), RGB(0,1,3), RGB(0,0,2), RGB(0,0,1), RGB(0,2,1)}, // fez
    {RGB(0,0,1), RGB(0,0,2), RGB(0,1,3), RGB(3,2,0), RGB(3,3,1)}, // gold on navy
    {RGB(2,1,0), RGB(0,2,2), RGB(1,3,2), RGB(3,3,2), RGB(3,1,0)}, // turquoise/terracotta
    {RGB(0,0,0), RGB(1,0,1), RGB(2,0,2), RGB(3,3,3), RGB(3,0,3)}, // night
};

// bass line, one note every 16 frames
static const u16 bass[8] = {
    NOTE(110), NOTE(110), NOTE(131), NOTE(110),
    NOTE(98),  NOTE(98),  NOTE(147), NOTE(131),
};

struct faller {
    int x, y, speed, kind;  // kind 0 = star (good), 1 = bomb
};

static struct faller stuff[4];
static int px;
static int level, n, lives;
static int beep;    // frames left on the "caught" sound
static int crash;   // frames left on the "hit a bomb" sound

static u32 seed = 12345;

static u32 random(void)
{
    seed ^= seed << 13;
    seed ^= seed >> 17;
    seed ^= seed << 5;
    return seed;
}

static void set_level(int lv)
{
    level = lv;
    const u8 *t = themes[lv & 3];
    for (int i = 0; i < 5; i++)
        GPU_PAL(i) = t[i];
    background(lv & 3, 0, 1);
    bitmap(1, 600, 16, 2, t[3], digits[lv]);   // line colour always stands out
}

static void new_faller(int i)
{
    stuff[i].x = 40 + random() % 560;
    stuff[i].y = 0;
    stuff[i].speed = 1 + level + random() % 3;
    stuff[i].kind = (random() % 4 == 0);   // 1 in 4 is a bomb
}

static void draw_faller(int i)
{
    if (stuff[i].kind)
        shape(i, stuff[i].x, stuff[i].y, 12, OCTAGON, RGB(3, 0, 0));
    else
        shape(i, stuff[i].x, stuff[i].y, 16, STAR, 0x3c);
}

static void sounds(u32 frame)
{
    int vol0 = 0, noise = 0;

    if (beep) {
        SND_VOICE0 = NOTE(880 + 40 * beep);
        vol0 = beep;
        beep--;
    }
    if (crash) {
        SND_NOISE = 8;
        noise = crash;
        crash--;
    }

    SND_VOICE1 = bass[(frame >> 4) & 7];
    int bassvol = 6 - ((frame >> 1) & 7);   // little "pluck" on each note
    if (bassvol < 0)
        bassvol = 0;

    SND_VOLUME = vol0 | (bassvol << 4) | (noise << 8);
}

static void new_game(void)
{
    px = 304;
    n = 0;
    lives = 3;
    set_level(0);
    for (int i = 0; i < 4; i++) {
        new_faller(i);
        stuff[i].y = -(i * 120);   // spread them out at the start
    }
}

static void game_over(void)
{
    sound_off();
    for (int i = 0; i < 4; i++)
        shape_off(i);
    BITMAP_CTRL(0) = 0;

    // red background until start is pressed
    GPU_PAL(0) = RGB(2, 0, 0);
    GPU_PATTERN = 0;
    while (!(buttons() & 4))
        wait_vblank();
}

int main(void)
{
    new_game();

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
                if (stuff[i].kind) {
                    crash = 15;
                    lives--;
                } else {
                    beep = 12;
                    n++;
                    if (n % 10 == 0)
                        set_level(level + 1);
                }
                new_faller(i);
            }
        }

        if (lives == 0) {
            game_over();
            new_game();
            continue;
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

        sounds(frame);
    }
}
