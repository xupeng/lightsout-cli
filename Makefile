SWIFTC ?= swiftc

.PHONY: build test clean
build: lightsout

lightsout: main.swift
	$(SWIFTC) -O -module-cache-path /tmp/lightsout-cli-module-cache main.swift -o lightsout

test:
	$(SWIFTC) -D TESTING -module-cache-path /tmp/lightsout-cli-module-cache main.swift tests.swift -o /tmp/lightsout-cli-tests
	/tmp/lightsout-cli-tests

clean:
	rm -f lightsout
