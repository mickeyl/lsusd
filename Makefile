.DEFAULT_GOAL := help

PYTHON ?= python3
PIP ?= $(PYTHON) -m pip
PIP_INSTALL_FLAGS ?= $(shell $(PYTHON) -c 'import sys; print("" if sys.prefix != sys.base_prefix else "--user --break-system-packages")')
XCODEGEN ?= xcodegen
XCODEBUILD ?= xcodebuild
MAC_PROJECT := macOS/LSUSD.xcodeproj
MAC_SCHEME := LSUSD
MAC_DERIVED_DATA ?= macOS/DerivedData
MAC_VERSION := $(shell awk '/MARKETING_VERSION:/ { print $$2; exit }' macOS/project.yml)
MAC_RELEASE_APP := $(MAC_DERIVED_DATA)/Build/Products/Release/LSUSD.app
MAC_DIST_DIR := macOS/Dist
MAC_DIST_ARCHIVE := $(MAC_DIST_DIR)/LSUSD-$(MAC_VERSION)-macOS.zip
MAC_SIGN_IDENTITY ?= Developer ID Application: Michael Lauer (NANNL9SK66)
NOTARY_PROFILE ?=

.PHONY: help install uninstall check run watch mac-generate mac-build mac-test mac-run mac-package mac-release clean

help:
	@echo "Targets:"
	@echo "  make install    Install this project editable into the active Python environment"
	@echo "  make uninstall  Uninstall the package from the active Python environment"
	@echo "  make check      Compile sources and show CLI help"
	@echo "  make run        Run lsusd from the source tree"
	@echo "  make watch      Run lsusd --watch from the source tree"
	@echo "  make mac-generate  Generate the macOS Xcode project"
	@echo "  make mac-build     Build the native macOS app"
	@echo "  make mac-test      Run the native core tests"
	@echo "  make mac-run       Build and launch the native macOS app"
	@echo "  make mac-package   Build and package the Developer ID release app"
	@echo "  make mac-release   Notarize and staple the Homebrew release archive"
	@echo "  make clean      Remove Python cache files"

install:
	$(PIP) install $(PIP_INSTALL_FLAGS) -e .

uninstall:
	$(PIP) uninstall -y lsusd

check:
	$(PYTHON) -m compileall -q src
	PYTHONPATH=src $(PYTHON) -m unittest discover -s tests
	PYTHONPATH=src $(PYTHON) -m lsusd --help

run:
	@PYTHONPATH=src $(PYTHON) -m lsusd

watch:
	@PYTHONPATH=src $(PYTHON) -m lsusd --watch || test $$? -eq 130

mac-generate:
	cd macOS && $(XCODEGEN) generate

mac-build: mac-generate
	$(XCODEBUILD) -project $(MAC_PROJECT) -scheme $(MAC_SCHEME) -configuration Debug -derivedDataPath $(MAC_DERIVED_DATA) build

mac-test:
	swift test --package-path macOS/Packages/LSUSDCore

mac-run: mac-build
	open "$(MAC_DERIVED_DATA)/Build/Products/Debug/LSUSD.app"

mac-package: mac-generate
	$(XCODEBUILD) -project $(MAC_PROJECT) -scheme $(MAC_SCHEME) -configuration Release -destination 'generic/platform=macOS' -derivedDataPath $(MAC_DERIVED_DATA) CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$(MAC_SIGN_IDENTITY)" DEVELOPMENT_TEAM=NANNL9SK66 ENABLE_HARDENED_RUNTIME=YES CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO OTHER_CODE_SIGN_FLAGS="--timestamp" build
	codesign --verify --deep --strict --verbose=2 "$(MAC_RELEASE_APP)"
	@if codesign -d --entitlements :- "$(MAC_RELEASE_APP)" 2>/dev/null | grep -q com.apple.security.get-task-allow; then \
		echo "ERROR: Release app contains com.apple.security.get-task-allow."; \
		exit 1; \
	fi
	mkdir -p "$(MAC_DIST_DIR)"
	rm -f "$(MAC_DIST_ARCHIVE)"
	ditto -c -k --keepParent --sequesterRsrc --zlibCompressionLevel 9 "$(MAC_RELEASE_APP)" "$(MAC_DIST_ARCHIVE)"
	shasum -a 256 "$(MAC_DIST_ARCHIVE)"

mac-release:
	@if [ -z "$(NOTARY_PROFILE)" ]; then \
		echo "ERROR: Set NOTARY_PROFILE to a notarytool keychain profile."; \
		exit 1; \
	fi
	$(MAKE) mac-package
	xcrun notarytool submit "$(MAC_DIST_ARCHIVE)" --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple "$(MAC_RELEASE_APP)"
	spctl -a -vvv -t exec "$(MAC_RELEASE_APP)"
	rm -f "$(MAC_DIST_ARCHIVE)"
	ditto -c -k --keepParent --sequesterRsrc --zlibCompressionLevel 9 "$(MAC_RELEASE_APP)" "$(MAC_DIST_ARCHIVE)"
	shasum -a 256 "$(MAC_DIST_ARCHIVE)"

clean:
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
	find . -type f -name '*.py[co]' -delete
	rm -rf macOS/DerivedData macOS/Dist macOS/Packages/LSUSDCore/.build
