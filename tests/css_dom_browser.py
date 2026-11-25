#!/usr/bin/env python3
"""Build a real Kryon DOM app and verify CSS IDs in private Chromium."""

import json
import os
from pathlib import Path
import re
import select
import shutil
import subprocess
import sys
import time
import tomllib

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "build" / "css-dom-project"
BROWSER_CSS = ROOT / "build" / "css-dom-browser.css"
ENV = dict(os.environ)
for name in ("DISPLAY", "WAYLAND_DISPLAY", "XAUTHORITY", "GDK_DISPLAY",
             "DBUS_SESSION_BUS_ADDRESS", "SESSION_MANAGER"):
    ENV.pop(name, None)
ENV["YUE_DESKTOP_RECOVERY"] = "0"
ENV.setdefault("EM_CACHE", str(ROOT / "build" / "emscripten-cache"))


def run(command, directory, timeout=300):
    subprocess.run(list(map(str, command)), cwd=directory, env=ENV, check=True,
                   timeout=timeout)


def package_path(ziran, name):
    result = subprocess.run([ziran, "pkg", "path", name], cwd=ROOT, env=ENV,
                            check=True, timeout=300, stdout=subprocess.PIPE, text=True)
    path = Path(result.stdout.rstrip("\n"))
    if not path.is_absolute() or not path.is_dir():
        raise ValueError(f"invalid Ziran package path for {name}: {result.stdout!r}")
    return str(path)


def build_project(ziran, css_source):
    with (ROOT / "ziran.toml").open("rb") as manifest_file:
        manifest = tomllib.load(manifest_file)
    toolchain = manifest["toolchain"]
    kryon = manifest["dependencies"]["kryon"]
    kryon_root = package_path(ziran, "kryon")
    quote = json.dumps
    shutil.rmtree(PROJECT, ignore_errors=True)
    (PROJECT / "src").mkdir(parents=True)
    (PROJECT / "ziran.toml").write_text(
        '[package]\nname = "css_dom"\nentry = "src/app.zi"\n'
        'module_roots = ["src"]\nbridge_modules = ["app"]\n\n'
        f'[toolchain]\ngit = {quote(toolchain["git"])}\nref = {quote(toolchain["ref"])}\n\n'
        f'[dependencies.kryon]\ngit = {quote(kryon["git"])}\nref = {quote(kryon["ref"])}\n\n'
        '[dependencies.css]\ngit = "https://github.com/kryonlabs/css.git"\nref = "master"\n\n'
        '[tool.kryon]\ndefault_profile = "web"\n\n'
        '[tool.kryon.profiles.web]\nbackend = "dom"\n'
    )
    (PROJECT / "ziran.local.toml").write_text(
        "[overrides]\n"
        f'kryon = {quote(kryon_root, ensure_ascii=False)}\n'
        f'css = {quote(str(css_source), ensure_ascii=False)}\n'
    )
    shutil.copyfile(ROOT / "tests" / "css_dom_app.zi", PROJECT / "src" / "app.zi")
    run([ziran, "lock"], PROJECT)
    run([ziran, "tool", "kryon", "build", "--profile", "web"], PROJECT)
    output = PROJECT / "build" / "css_dom-web.html"
    if not output.is_file() or output.stat().st_size < 100_000:
        raise AssertionError("the production DOM page was not generated")
    if not (PROJECT / "build/generated/web/ir/kryon_program_host.zir").is_file():
        raise AssertionError("the DOM runner saved IR was not generated")
    if not (PROJECT / "build/generated/web/c/kryon_program_host.c").is_file():
        raise AssertionError("the DOM runner C source was not generated")
    return output


class Chromium:
    def __init__(self, profile):
        self.profile = profile
        self.diagnostics = []
        self.received = b""
        self.sequence = 0
        self.session = None
        environment = dict(ENV)
        browser = os.environ.get("CHROMIUM", "chromium")
        self.process = subprocess.Popen(
            ["sh", "-c", 'exec 3<&0 4>&1 "$@" </dev/null >/dev/null', "chromium", browser,
             "--headless", "--no-sandbox", "--disable-gpu", "--use-gl=disabled",
             "--disable-dev-shm-usage", "--no-first-run", "--no-default-browser-check",
             "--remote-debugging-pipe", "--user-data-dir=" + str(profile), "about:blank"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=(profile / "chromium.log").open("wb"), env=environment)

    def command(self, method, **params):
        self.sequence += 1
        message = {"id": self.sequence, "method": method, "params": params}
        if self.session:
            message["sessionId"] = self.session
        self.process.stdin.write(json.dumps(message).encode() + b"\0")
        self.process.stdin.flush()
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            while b"\0" in self.received:
                raw, self.received = self.received.split(b"\0", 1)
                if not raw:
                    continue
                reply = json.loads(raw)
                if reply.get("method") == "Runtime.exceptionThrown":
                    detail = reply["params"].get("exceptionDetails", {})
                    self.diagnostics.append((detail.get("exception") or {}).get("description")
                                            or detail.get("text"))
                if reply.get("id") == self.sequence:
                    if "error" in reply:
                        raise RuntimeError(method + ": " + json.dumps(reply["error"]))
                    return reply.get("result", {})
            if select.select([self.process.stdout], [], [], 0.5)[0]:
                data = os.read(self.process.stdout.fileno(), 1 << 20)
                if not data:
                    raise RuntimeError("Private Chromium exited; see " + str(self.profile / "chromium.log"))
                self.received += data
        raise TimeoutError(method)

    def evaluate(self, expression):
        result = self.command("Runtime.evaluate", expression=expression, returnByValue=True)
        if "exceptionDetails" in result:
            raise RuntimeError(json.dumps(result["exceptionDetails"])[:4000])
        return result.get("result", {}).get("value")

    def until(self, expression, description):
        deadline = time.monotonic() + 30
        last = None
        while time.monotonic() < deadline:
            last = self.evaluate(expression)
            if last:
                return last
            time.sleep(0.05)
        raise AssertionError("Timed out waiting for " + description + ": " + repr(last))

    def close(self):
        try:
            self.command("Browser.close")
        except Exception:
            pass
        try:
            self.process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self.process.terminate()
            self.process.wait(timeout=10)


INITIAL_SNAPSHOT = r"""
(() => {
  const root = document.querySelector('#kryon-dom-root');
  const buttons = root ? [...root.querySelectorAll('button')] : [];
  const save = buttons.find(node => node.textContent === 'Save');
  const other = buttons.find(node => node.textContent === 'Other');
  const state = buttons.find(node => node.textContent === 'State');
  const plain = buttons.find(node => node.textContent === 'Plain');
  globalThis.__cssDomInitial = {save, other, state, plain, parent: save && save.parentElement,
    order: buttons.map(node => node.textContent)};
  return !!(root && save && other && state && plain && globalThis.__cssDomMinHeight === 64);
})()
"""


UPDATED_SNAPSHOT = r"""
(() => {
  const root = document.querySelector('#kryon-dom-root');
  const buttons = root ? [...root.querySelectorAll('button')] : [];
  const save = buttons.find(node => node.textContent === 'Save updated');
  const other = buttons.find(node => node.textContent === 'Other');
  const state = buttons.find(node => node.textContent === 'State');
  const plain = buttons.find(node => node.textContent === 'Plain');
  const initial = globalThis.__cssDomInitial || {};
  return !!(root && save && other && state && plain &&
    initial.save === save && initial.other === other &&
    initial.state === state && initial.plain === plain &&
    initial.parent === save.parentElement &&
    buttons.map(node => node.textContent).join('|') === 'Other|Save updated|State|Plain');
})()
"""


STYLE_SNAPSHOT = r"""
(() => {
  const root = document.querySelector('#kryon-dom-root');
  const buttons = root ? [...root.querySelectorAll('button')] : [];
  const save = buttons.find(node => node.textContent === 'Save updated');
  const other = buttons.find(node => node.textContent === 'Other');
  const state = buttons.find(node => node.textContent === 'State');
  const plain = buttons.find(node => node.textContent === 'Plain');
  if (!save || !other || !state || !plain) return null;
  const style = getComputedStyle(save);
  return {
    ids: {save: save.getAttribute('data-kryon-id'),
          other: other.getAttribute('data-kryon-id'), state: state.getAttribute('data-kryon-id')},
    plainId: plain.getAttribute('data-kryon-id'),
    plainClass: plain.getAttribute('data-kryon-class'),
    saveMinHeight: style.minHeight,
    saveFontSize: style.fontSize,
    saveWeight: style.fontWeight,
    saveFontStyle: style.fontStyle,
    saveTracking: style.letterSpacing,
    saveLineRatio: Number(style.lineHeight.replace('px', '')) / Number(style.fontSize.replace('px', '')),
    saveFamily: style.fontFamily,
    saveColor: style.color.match(/^color\(srgb ([^/]+)\)$/)?.[1].trim().split(/\s+/).map(value => Math.round(Number(value) * 255)),
    saveBackground: style.backgroundColor,
    saveTransitionDuration: style.transitionDuration,
    saveTransitionTiming: style.transitionTimingFunction,
    otherSelectedBackground: getComputedStyle(other).backgroundColor,
    stateSelected: state.getAttribute('data-kryon-selected'),
    statePressed: state.getAttribute('aria-pressed'),
    stateBackground: getComputedStyle(state).backgroundColor,
    plainBackground: getComputedStyle(plain).backgroundColor,
    typed: {ink: globalThis.__cssDomInk,
             minHeight: globalThis.__cssDomMinHeight, lineHeight: globalThis.__cssDomLineHeight,
             lineUnit: globalThis.__cssDomLineUnit, weight: globalThis.__cssDomWeight,
             style: globalThis.__cssDomFontStyle, tracking: globalThis.__cssDomTracking,
             typeface: globalThis.__cssDomTypeface, duration: globalThis.__cssDomMotionDuration,
             multiplier: globalThis.__cssDomMotionMultiplier}
  };
})()
"""


def verify(output):
    source = BROWSER_CSS.read_text()
    if "#kryon-dom-root { --save-motion: 123ms; }" not in source:
        raise AssertionError("the canonical exporter did not write the motion custom property")
    if "@media (prefers-reduced-motion: reduce) {" not in source:
        raise AssertionError("the canonical exporter did not preserve reduced motion")
    profile = PROJECT / "browser-profile"
    shutil.rmtree(profile, ignore_errors=True)
    profile.mkdir(parents=True)
    browser = Chromium(profile)
    try:
        target = next(item["targetId"] for item in browser.command("Target.getTargets")["targetInfos"]
                      if item["type"] == "page")
        browser.session = browser.command("Target.attachToTarget", targetId=target, flatten=True)["sessionId"]
        browser.command("Runtime.enable")
        browser.command("Page.enable")
        browser.command("Emulation.setDeviceMetricsOverride", width=320, height=520,
                        deviceScaleFactor=1, mobile=False)
        browser.command("Page.navigate", url=output.as_uri())
        browser.until(INITIAL_SNAPSHOT, "the initial DOM tree")
        browser.evaluate("globalThis.__cssDomUpdate = true")
        browser.until(UPDATED_SNAPSHOT, "identity-preserving DOM update")
        values = browser.until(STYLE_SNAPSHOT, "computed CSS values")
        if values["plainId"] is not None:
            raise AssertionError("a zero style ID was exported: " + repr(values["plainId"]))
        if not values["plainClass"] or values["plainClass"] == "0":
            raise AssertionError("the class baseline was not exported")
        ids = values["ids"]
        if not ids["save"] or not ids["other"] or not ids["state"] or len(set(ids.values())) != 3:
            raise AssertionError("distinct style IDs were not exported: " + repr(ids))
        for name, value in ids.items():
            selector = f'[data-kryon-id="{value}"]'
            if selector not in source:
                raise AssertionError(f"exported CSS lacks {name} selector {selector}")
        expected = {
            "saveMinHeight": "64px", "saveFontSize": "17px", "saveBackground": "rgb(16, 32, 48)",
            "saveColor": [232, 216, 200],
            "saveWeight": "650", "saveFontStyle": "italic", "saveTracking": "-0.5px",
            "saveTransitionDuration": "0.123s", "saveTransitionTiming": "linear",
            "otherSelectedBackground": "rgb(48, 32, 16)", "stateSelected": "true", "statePressed": "true",
            "stateBackground": "rgb(64, 80, 96)", "plainBackground": "rgb(17, 17, 17)",
        }
        for name, expected_value in expected.items():
            if values[name] != expected_value:
                raise AssertionError(f"{name}: expected {expected_value!r}, got {values[name]!r}")
        if abs(values["saveLineRatio"] - 1.4) > 0.01:
            raise AssertionError("line-height ratio: " + repr(values["saveLineRatio"]))
        if "Kryon Css Test" not in values["saveFamily"]:
            raise AssertionError("font family: " + repr(values["saveFamily"]))
        typed = values["typed"]
        if (typed["ink"] != 0xE8D8C8FF or
                typed["minHeight"] != 64 or abs(typed["lineHeight"] - 1.4) > 0.001 or
                typed["typeface"] != "Kryon Css Test" or typed["duration"] != 123 or
                typed["multiplier"] != 1.25 or typed["lineUnit"] != 1 or
                typed["weight"] != 650 or typed["style"] != 2 or typed["tracking"] != -0.5):
            raise AssertionError("native typed values: " + repr(typed))
        browser.command("Emulation.setEmulatedMedia", features=[
            {"name": "prefers-reduced-motion", "value": "reduce"}])
        reduced = browser.until("(() => { const save = [...document.querySelectorAll('button')]"
                                ".find(node => node.textContent === 'Save updated'); "
                                "return {reduce: matchMedia('(prefers-reduced-motion: reduce)').matches, "
                                "duration: getComputedStyle(save).transitionDuration}; })()",
                      "the reduced-motion browser preference")
        browser.command("Emulation.setEmulatedMedia", features=[])
        unreduced = browser.until("(() => { const save = [...document.querySelectorAll('button')]"
                                  ".find(node => node.textContent === 'Save updated'); "
                                  "return {noPreference: matchMedia('(prefers-reduced-motion: no-preference)').matches, "
                                  "duration: getComputedStyle(save).transitionDuration}; })()",
                      "the no-preference browser preference")
        if not reduced["reduce"] or reduced["duration"] != "0s":
            raise AssertionError("reduced-motion browser preference: " + repr(reduced))
        if not unreduced["noPreference"] or unreduced["duration"] != "0.123s":
            raise AssertionError("no-preference browser preference: " + repr(unreduced))
        if browser.diagnostics:
            raise AssertionError("browser exceptions: " + repr(browser.diagnostics))
    finally:
        browser.close()


def main():
    ziran = shutil.which(os.environ.get("ZIRAN", "ziran"))
    if ziran is None:
        raise FileNotFoundError("could not find the configured Ziran executable")
    css_source = Path(os.environ.get("CSS_DOM_SOURCE", ROOT)).resolve()
    css_tool = ROOT / "build" / "tools" / "css_tool"
    if not css_tool.is_file():
        raise AssertionError("missing " + str(css_tool))
    run([css_tool, "export", ROOT / "tests" / "css_dom.css", BROWSER_CSS], ROOT)
    output = build_project(Path(ziran).absolute(), css_source)
    verify(output)
    print("css DOM production host: IDs, compound state, styles and identity PASS")


if __name__ == "__main__":
    main()
