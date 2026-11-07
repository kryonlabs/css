// A C++ host linking the style code as a C library, as C++ apps do.
// Prints the digests in the C program's format.
#include <cstdint>
#include <cstdio>

extern "C" {
uint32_t CssConformanceDigest(int32_t pack, int32_t theme);
int32_t CssConformanceAll(void);
}

int main() {
    const char *packs[] = {"classic", "material", "lightfield"};
    const char *themes[] = {"light", "dark"};
    for (int32_t pack = 0; pack < 3; ++pack) {
        for (int32_t theme = 0; theme < 2; ++theme) {
            std::printf("%s %s %u\n", packs[pack], themes[theme],
                static_cast<unsigned>(CssConformanceDigest(pack, theme)));
        }
    }
    std::printf("all %d\n", static_cast<int>(CssConformanceAll()));
    return 0;
}
