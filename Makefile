.DEFAULT_GOAL := check

ZIRAN ?= ziran
CC ?= cc
BUILD := build
FUZZ_SEED ?= 1
FUZZ_COUNT ?= 2000
STYLE_PACKS := classic material lightfield
CSS_TOOL := $(BUILD)/tools/css_tool
INCLUDE = -I$$($(ZIRAN) pkg path ziran)/include

.PHONY: check test conformance style-packs style-pack-check migrate fuzz clean

check: test conformance style-pack-check fuzz

# A behavior test: build one Ziran entry to C and run it.
define native_test
	rm -rf $(BUILD)/$(1)-c
	$(ZIRAN) build --project --target=c --entry $(1):main -o $(BUILD)/$(1)-c tests/$(1).zi
	$(CC) -std=c11 -O1 $(INCLUDE) -I$(BUILD)/$(1)-c $(BUILD)/$(1)-c/*.c -o $(BUILD)/$(1) -lm
	$(BUILD)/$(1)
endef

test:
	$(ZIRAN) check --project
	$(ZIRAN) check --project src/css_lexer_laws.zi
	$(call native_test,css_parse_behavior)
	$(call native_test,css_sheet_behavior)
	$(call native_test,css_format_behavior)
	$(call native_test,css_migrate_behavior)
	$(call native_test,css_export_behavior)
	$(call native_test,system_style_behavior)

# The same sheets resolved on every code generation target, plus the
# browser export; see tests/css_conformance.sh.
conformance:
	ZIRAN=$(ZIRAN) sh tests/css_conformance.sh

$(CSS_TOOL): tools/css_tool.zi src/*.zi src/parser/*.zi
	rm -rf $@-c
	mkdir -p $(dir $@)
	$(ZIRAN) build --project --target=c --entry css_tool:main -o $@-c tools/css_tool.zi
	$(CC) -std=c11 -O2 $(INCLUDE) -I$@-c $@-c/*.c -o $@ -lm

# Packs are compiled into rule tables apps load without parsing. The
# modules are committed, because apps import this package without running
# its Makefile; style-pack-check fails when one no longer matches its CSS.
style-packs: $(CSS_TOOL)
	@for pack in $(STYLE_PACKS); do $(CSS_TOOL) pack $$pack || exit 1; done

style-pack-check: $(CSS_TOOL)
	@for pack in $(STYLE_PACKS); do $(CSS_TOOL) pack-check $$pack || exit 1; done
	@echo "Style pack modules match: $(STYLE_PACKS)"

# Convert a KSS sheet: make migrate IN=old.kss OUT=new.css
migrate: $(CSS_TOOL)
	$(CSS_TOOL) migrate $(IN) $(OUT)

# Generated and damaged sheets through the parser, the sheet, the formatter
# and the exporter, built with AddressSanitizer and UndefinedBehaviorSanitizer.
# The same seed makes the same sheets; see tests/css_fuzz.zi.
fuzz:
	@ZIRAN=$(ZIRAN) sh tests/css_fuzz.sh $(FUZZ_SEED) $(FUZZ_COUNT)

clean:
	rm -rf $(BUILD)
