.PHONY: test lint lint-fix run android android-release android-debug web web-debug clean signal-dev help

# Python env
VENV    ?= ../fastapi_env
PYTHON  ?= $(VENV)/bin/python3
GDLINT  ?= $(VENV)/bin/gdlint
GDFORMAT ?= $(VENV)/bin/gdformat

# Godot executable (override with GODOT=path/to/godot)
GODOT   ?= /var/lib/flatpak/exports/bin/org.godotengine.Godot

# Directories to lint/test
GD_SOURCES := scripts/ tests/

# ── Tests (GUT) ─────────────────────────────────────────────────────────────
test:
	$(GODOT) --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit --path .

# ── Run ─────────────────────────────────────────────────────────────────────
run:
	flatpak run org.godotengine.Godot --path .

# ── Linting ─────────────────────────────────────────────────────────────────
lint:
	$(GDLINT) $(GD_SOURCES)

lint-fix:
	$(GDFORMAT) $(GD_SOURCES)

# ── Android export ──────────────────────────────────────────────────────────
android android-release:
	GODOT=$(GODOT) ./build-android.sh

android-debug:
	GODOT=$(GODOT) BUILD_MODE=debug ./build-android.sh

# ── Web export ──────────────────────────────────────────────────────────────
web:
	GODOT=$(GODOT) ./build-web.sh

web-debug:
	GODOT=$(GODOT) BUILD_MODE=debug ./build-web.sh

# ── Signaling ───────────────────────────────────────────────────────────────
SIGNAL_DIR ?= tools/webrtc_signaling
DENO      ?= deno

signal-dev:
	cd $(SIGNAL_DIR) && $(DENO) run --allow-net --unstable-kv server.ts

# ── Clean ───────────────────────────────────────────────────────────────────
clean:
	rm -rf android/ export/ScrabbleProject.apk export/web/

# ── Help ────────────────────────────────────────────────────────────────────
help:
	@echo "Targets:"
	@echo "  test       Run GUT unit tests in headless Godot"
	@echo "  run        Run the game with flatpak Godot"
	@echo "  lint       Run gdlint on scripts/ and tests/"
	@echo "  lint-fix   Auto-format scripts/ and tests/ with gdformat"
	@echo "  android        Build Android APK (release)"
	@echo "  android-debug  Build Android APK (debug)"
	@echo "  web            Build Web (HTML5) export (release)"
	@echo "  web-debug      Build Web (HTML5) export (debug)"
	@echo "  signal-dev     Run the local WebRTC signaling server"
	@echo "  clean          Remove Android/Web build artifacts"
	@echo ""
	@echo "Variables:"
	@echo "  GODOT=$(GODOT)     Godot executable path"
	@echo "  GDLINT=$(GDLINT)   gdlint command (from $(VENV))"
	@echo "  GDFORMAT=$(GDFORMAT)"
