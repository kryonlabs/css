package ziran

import (
	"fmt"
	"testing"
)

// Prints the digests in the C program's format; tests/css_conformance.sh
// compares them with tests/css_conformance.expected.
func TestCssConformance(t *testing.T) {
	for pack := int32(0); pack < 3; pack++ {
		for theme := int32(0); theme < 2; theme++ {
			name := "light"
			if theme == 1 {
				name = "dark"
			}
			fmt.Printf("conformance %s %s %d\n", CssConformance_PackName(pack), name,
				CssConformance_CssConformanceDigest(pack, theme))
		}
	}
	fmt.Printf("conformance all %d\n", CssConformance_CssConformanceAll())
}
