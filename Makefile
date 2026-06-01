SWIFTFORMAT := .nest/bin/swiftformat
SWIFTLINT := .nest/bin/swiftlint
MYSWIFTLINTER := .nest/bin/my-swift-linter
PERIPHERY := .nest/bin/periphery
DOCSYNC := .nest/bin/docsync
GITNAGG := .nest/bin/gitnagg

.PHONY: install-commands setup format format-lint lint my-swift-lint periphery gitnagg hooks test build release docsync docsync-update-checksum check

install-commands:
	./scripts/nest.sh bootstrap nestfile.yaml

setup: install-commands hooks
	@if command -v mise >/dev/null 2>&1; then mise install; else echo "mise not found; skipping mise install"; fi

format:
	@test -x "$(SWIFTFORMAT)" || (echo "Run: make install-commands" && exit 1)
	"$(SWIFTFORMAT)" --config .swiftformat .

format-lint:
	@test -x "$(SWIFTFORMAT)" || (echo "Run: make install-commands" && exit 1)
	"$(SWIFTFORMAT)" --lint --config .swiftformat .

lint:
	@test -x "$(SWIFTLINT)" || (echo "Run: make install-commands" && exit 1)
	"$(SWIFTLINT)" lint --config .swiftlint.yml --strict

my-swift-lint:
	@test -x "$(MYSWIFTLINTER)" || (echo "Run: make install-commands" && exit 1)
	"$(MYSWIFTLINTER)" --config .swift-ast-lint.yml

periphery:
	@test -x "$(PERIPHERY)" || (echo "Run: make install-commands" && exit 1)
	"$(PERIPHERY)" scan --quiet

gitnagg:
	@test -x "$(GITNAGG)" || (echo "Run: make install-commands" && exit 1)
	"$(GITNAGG)" check --config .gitnagg.yml

hooks:
	./scripts/setup-hooks.sh

test:
	swift test

build:
	swift build

release:
	swift build -c release

docsync:
	@test -x "$(DOCSYNC)" || (echo "Run: make install-commands" && exit 1)
	"$(DOCSYNC)" check --config docsync.yml

docsync-update-checksum:
	@test -x "$(DOCSYNC)" || (echo "Run: make install-commands" && exit 1)
	"$(DOCSYNC)" update-checksum --config docsync.yml

check: format-lint lint my-swift-lint test docsync
