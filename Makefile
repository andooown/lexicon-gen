.PHONY: build
build:
	@swift build

.PHONY: test
test:
	@swift test

.PHONY: clean
clean:
	@rm -rf \
		./.build
