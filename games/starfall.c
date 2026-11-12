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

int main(void)
{
    GPU_PATTERN = STAR_CROSS | (1 << 4) | (1 << 5);

    int player_x = 304;
    bitmap(0, player_x, 420, 2, RGB(3, 2, 0), lantern);

    while (1) {
        wait_vblank();

        u32 b = buttons();
        if ((b & 1) && player_x > 4)
            player_x -= 6;
        if ((b & 2) && player_x < 604)
            player_x += 6;
        BITMAP_X(0) = player_x;
    }
}
