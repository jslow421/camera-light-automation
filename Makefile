LABEL  := dev.jslowik.litra-cam
PREFIX ?= /usr/local
BIN    := $(PREFIX)/bin/litra-cam
PLIST  := $(HOME)/Library/LaunchAgents/$(LABEL).plist
LOG    := $(HOME)/Library/Logs/litra-cam.log
UID_   := $(shell id -u)

.PHONY: build install redeploy uninstall

build:
	swiftc -O src/litra-cam.swift -framework CoreMediaIO -o litra-cam

install: build
	mkdir -p $(dir $(PLIST)) $(HOME)/Library/Logs
	if [ -w $(PREFIX)/bin ]; then install -m 755 litra-cam $(BIN); else sudo install -m 755 litra-cam $(BIN); fi
	sed -e 's|@BIN@|$(BIN)|g' -e 's|@LOG@|$(LOG)|g' src/launch-agent > $(PLIST)
	-launchctl bootout gui/$(UID_)/$(LABEL) 2>/dev/null
	launchctl bootstrap gui/$(UID_) $(PLIST)

redeploy: install
	launchctl kickstart -k gui/$(UID_)/$(LABEL)

uninstall:
	-launchctl bootout gui/$(UID_)/$(LABEL) 2>/dev/null
	rm -f $(PLIST)
	if [ -w $(PREFIX)/bin ]; then rm -f $(BIN); else sudo rm -f $(BIN); fi
