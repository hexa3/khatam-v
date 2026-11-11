// Starfall

#include "khatam.h"

int main(void)
{
    int pattern = 0;

    while (1) {
        // buttons pick the pattern for now
        u32 b = BUTTONS;
        if (b & 1)
            pattern = 0;
        if (b & 2)
            pattern = 1;
        if (b & 4)
            pattern = 2;
        if (b & 8)
            pattern = 3;
        GPU_PATTERN = pattern | (1 << 4) | (1 << 5);
    }
}
