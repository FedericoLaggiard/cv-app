export PUB_HOSTED_URL := https://pub.dev

REPORT_DIR := build/ci

.PHONY: setup-hooks analyze test complexity check-registry ci-fast

setup-hooks:
	dart run husky install

check-registry:
	@bad=$$(grep -oE 'url: "[^"]*"' pubspec.lock | sort -u | grep -v 'url: "https://pub\.dev"' || true); \
	if [ -n "$$bad" ]; then \
		echo "pubspec.lock references a non-pub.dev registry:"; \
		echo "$$bad"; \
		echo "Regenerate the lockfile with PUB_HOSTED_URL=https://pub.dev flutter pub get."; \
		exit 1; \
	fi; \
	echo "pubspec.lock: registry OK (pub.dev)"

analyze:
	flutter analyze --fatal-infos --fatal-warnings

test:
	flutter test

complexity:
	@mkdir -p $(REPORT_DIR)
	dart run dart_code_linter:metrics analyze lib/src/domain lib/src/repository lib/src/photo \
		--cyclomatic-complexity=10 --maximum-nesting-level=5 \
		--set-exit-on-violation-level=warning \
		--json-path=$(REPORT_DIR)/complexity-core.json
	dart run dart_code_linter:metrics analyze lib/src/ui lib/src/app \
		--cyclomatic-complexity=20 --maximum-nesting-level=5 \
		--set-exit-on-violation-level=warning \
		--json-path=$(REPORT_DIR)/complexity-ui-app.json

ci-fast: check-registry analyze test complexity
