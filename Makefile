SWIFTC ?= swiftc

.PHONY: build clean
build: lightsout

lightsout: main.swift
	$(SWIFTC) -O -module-cache-path /tmp/lightsout-cli-module-cache main.swift -o lightsout

clean:
	rm -f lightsout
