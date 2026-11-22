.DEFAULT_GOAL := check

ZIRAN ?= ziran
CC ?= cc
BUILD := build
FUZZ_SEED ?= 1
FUZZ_COUNT ?= 2000
STYLE_PACKS := classic material lightfield
CSS_TOOL := $(BUILD)/tools/css_tool
INCLUDE = -I$$($(ZIRAN) pkg path ziran)/include

.PHONY: check test conformance style-packs style-pack-check diagnostics-test format export css-dom-test motion-test fuzz clean

check: test conformance style-pack-check css-dom-test motion-test fuzz

# A behavior test: build one Ziran entry to C and run it.
define native_test
	rm -rf $(BUILD)/$(1)-c
	$(ZIRAN) build --project $(2) --target=c --exe --entry $(1):main -o $(BUILD)/$(1)-c tests/$(1).zi
	$(CC) -std=c11 -O1 $(INCLUDE) -I$(BUILD)/$(1)-c $(BUILD)/$(1)-c/*.c -o $(BUILD)/$(1) -lm
	$(BUILD)/$(1)
endef

test: diagnostics-test $(BUILD)/layout-pack/style_pack_layout.zi
	$(ZIRAN) check --project src/Css/module.zi
	$(ZIRAN) check --project src/css_lexer_laws.zi
	$(call native_test,css_parse_behavior)
	$(call native_test,css_sheet_behavior)
	$(call native_test,css_format_behavior)
	$(call native_test,css_export_behavior)
	$(call native_test,css_integration_behavior,--module-path $(BUILD)/layout-pack)

$(BUILD)/layout-pack/style_pack_layout.zi: tests/css_layout.css $(CSS_TOOL)
	mkdir -p $(dir $@)
	$(CSS_TOOL) pack-file layout $< $@

# Production retained widgets on a Kryon checkout with declarative motion.
$(BUILD)/motion-pack/style_pack_motion.zi: tests/css_motion.css $(CSS_TOOL)
	mkdir -p $(dir $@)
	$(CSS_TOOL) pack-file motion $< $@

motion-test: $(BUILD)/motion-pack/style_pack_motion.zi
	$(call native_test,css_motion_behavior,--module-path $(BUILD)/motion-pack)

# The same sheets resolved on every code generation target, plus the
# browser export; see tests/css_conformance.sh.
conformance:
	ZIRAN=$(ZIRAN) sh tests/css_conformance.sh

$(CSS_TOOL): tools/css_tool.zi src/*.zi src/parser/*.zi
	rm -rf $@-c
	mkdir -p $(dir $@)
	$(ZIRAN) build --project --target=c --exe --entry css_tool:main -o $@-c tools/css_tool.zi
	$(CC) -std=c11 -O2 $(INCLUDE) -I$@-c $@-c/*.c -o $@ -lm

diagnostics-test: $(CSS_TOOL)
	$(CSS_TOOL) check --strict styles/classic.css
	$(CSS_TOOL) check tests/css_diagnostics.css 2>$(BUILD)/css-diagnostics.log
	@if $(CSS_TOOL) check --strict tests/css_diagnostics.css 2>$(BUILD)/css-diagnostics-strict.log; then exit 1; else test $$? -eq 1; fi
	cmp $(BUILD)/css-diagnostics.log $(BUILD)/css-diagnostics-strict.log
	grep -Fx "tests/css_diagnostics.css:5:3: web-only declaration 'text-transform': declaration is applied only by the browser" $(BUILD)/css-diagnostics.log
	grep -Fx "tests/css_diagnostics.css:14:1: skipped at-rule '@supports': at-rule 'supports' is outside Kryon CSS" $(BUILD)/css-diagnostics.log

# Packs are compiled into rule tables apps load without parsing. The
# modules are committed, because apps import this package without running
# its Makefile; style-pack-check fails when one no longer matches its CSS.
style-packs: $(CSS_TOOL)
	@for pack in $(STYLE_PACKS); do $(CSS_TOOL) pack $$pack || exit 1; done

style-pack-check: $(CSS_TOOL)
	$(CSS_TOOL) properties-check README.md
	@for pack in $(STYLE_PACKS); do $(CSS_TOOL) pack-check $$pack || exit 1; done
	@for pack in $(STYLE_PACKS); do $(CSS_TOOL) format-check styles/$$pack.css || exit 1; done
	@echo "Style pack modules match and are formatted: $(STYLE_PACKS)"

# Rewrite sheets in the standard layout: make format FILES="a.css b.css"
format: $(CSS_TOOL)
	@for file in $(FILES); do $(CSS_TOOL) format $$file || exit 1; done

# Export browser CSS: make export IN=app.css OUT=browser.css
export: $(CSS_TOOL)
	$(CSS_TOOL) export $(IN) $(OUT)

# A real Kryon web project, its production DOM writer and private Chromium.
css-dom-test: $(CSS_TOOL)
	ZIRAN="$(ZIRAN)" python3 tests/css_dom_browser.py

# Generated and damaged sheets through the parser, the sheet, the formatter
# and the exporter, built with AddressSanitizer and UndefinedBehaviorSanitizer.
# The same seed makes the same sheets; see tests/css_fuzz.zi.
fuzz:
	@ZIRAN=$(ZIRAN) sh tests/css_fuzz.sh $(FUZZ_SEED) $(FUZZ_COUNT)

clean:
	rm -rf $(BUILD)
