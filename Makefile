# FitTracker Makefile
# Primary target: `make tokens` — regenerates DesignTokens.swift from design-tokens/tokens.json
# CI target: `make tokens-check` — fails if DesignTokens.swift is out of sync with tokens.json

.PHONY: tokens tokens-check install

# Regenerate DesignTokens.swift from tokens.json via Style Dictionary
tokens: node_modules
	node node_modules/.bin/style-dictionary build --config sd.config.js
	@echo "✅  DesignTokens.swift regenerated"

# CI gate: verify committed DesignTokens.swift matches what make tokens would produce
tokens-check: node_modules
	node scripts/check-tokens.js

# Install npm dependencies (style-dictionary)
install:
	npm install

# Auto-install on first run
node_modules:
	npm install --silent
