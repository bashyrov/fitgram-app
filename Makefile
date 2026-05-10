.PHONY: help generate build test lint format clean bootstrap open

SCHEME    ?= Mealgram
DESTINATION ?= platform=iOS Simulator,name=iPhone 16 Pro,OS=latest
DERIVED   ?= build/DerivedData

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS=":.*## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Install required CLI tools (one-time)
	@which xcodegen      >/dev/null || brew install xcodegen
	@which swiftlint     >/dev/null || brew install swiftlint
	@which swift-format  >/dev/null || brew install swift-format
	@which xcbeautify    >/dev/null || brew install xcbeautify

generate: ## Regenerate Xcode project from project.yml
	xcodegen generate

open: generate ## Generate and open in Xcode
	open Mealgram.xcodeproj

build: ## Build app for iOS simulator
	set -o pipefail && xcodebuild \
	  -scheme $(SCHEME) \
	  -destination '$(DESTINATION)' \
	  -derivedDataPath $(DERIVED) \
	  -skipPackagePluginValidation \
	  -skipMacroValidation \
	  build | xcbeautify

test: ## Run unit + UI tests
	set -o pipefail && xcodebuild \
	  -scheme $(SCHEME) \
	  -destination '$(DESTINATION)' \
	  -derivedDataPath $(DERIVED) \
	  -enableCodeCoverage YES \
	  test | xcbeautify

lint: ## Run SwiftLint
	swiftlint --strict

format: ## Format Swift sources in-place
	swift-format format --in-place --recursive --configuration .swift-format Mealgram MealgramTests MealgramUITests

format-check: ## Verify formatting (CI)
	swift-format lint --recursive --configuration .swift-format Mealgram MealgramTests MealgramUITests

clean: ## Wipe build artifacts
	rm -rf build $(DERIVED) DerivedData
