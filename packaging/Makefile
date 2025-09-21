.PHONY: build clean install test help

# Package configuration
PACKAGE_NAME := pds
VERSION := 1.0.0
ARCH := all
DIST_DIR := dist

help: ## Show this help message
	@echo "PDS Package Build System"
	@echo "========================"
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: clean ## Build the .deb package
	@echo "Building $(PACKAGE_NAME) v$(VERSION)..."
	@mkdir -p $(DIST_DIR)
	@mkdir -p usr/share/pds
	@# Create VERSION file if it doesn't exist (for local builds)
	@if [ ! -f usr/share/pds/VERSION ]; then \
		echo "$(VERSION)" > usr/share/pds/VERSION; \
		echo "Created temporary VERSION file for local build"; \
	fi
	@chmod +x scripts/postinstall.sh scripts/preremove.sh
	@chmod +x bin/pds
	@nfpm pkg --packager deb --config nfpm.yaml --target $(DIST_DIR)/
	@echo "✅ Package built: $(DIST_DIR)/$(PACKAGE_NAME)_$(VERSION)_$(ARCH).deb"

clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	@rm -rf $(DIST_DIR)
	@# Remove temporary VERSION file if it exists
	@if [ -f usr/share/pds/VERSION ]; then \
		rm -f usr/share/pds/VERSION; \
		rmdir usr/share/pds 2>/dev/null || true; \
		rmdir usr/share 2>/dev/null || true; \
		rmdir usr 2>/dev/null || true; \
	fi
	@echo "✅ Cleaned"

install: build ## Install the package locally (requires sudo)
	@echo "Installing $(PACKAGE_NAME) locally..."
	@sudo dpkg -i $(DIST_DIR)/$(PACKAGE_NAME)_$(VERSION)_$(ARCH).deb || true
	@sudo apt-get install -f -y
	@echo "✅ Package installed. Open a new shell to use PDS functions."

uninstall: ## Uninstall the package
	@echo "Uninstalling $(PACKAGE_NAME)..."
	@sudo apt-get remove -y $(PACKAGE_NAME) || true
	@echo "✅ Package uninstalled"

test: build ## Test the package installation in a Docker container
	@echo "Testing package installation..."
	@PACKAGE_FILE=$$(ls -t $(DIST_DIR)/$(PACKAGE_NAME)_*_$(ARCH).deb 2>/dev/null | head -1); \
	if [ -z "$$PACKAGE_FILE" ]; then \
		echo "❌ No package file found in $(DIST_DIR)"; \
		exit 1; \
	fi; \
	echo "Testing package: $$(basename $$PACKAGE_FILE)"; \
	docker run --rm -v $(PWD)/$(DIST_DIR):/packages ubuntu:22.04 /bin/bash -c " \
		apt-get update && \
		apt-get install -y /packages/$$(basename $$PACKAGE_FILE) && \
		pds doctor && \
		echo 'Package test completed successfully' \
	"

lint: ## Run shellcheck on all scripts
	@echo "Running shellcheck on scripts..."
	@find ../bash -name "*.sh" -exec shellcheck {} \; || true
	@shellcheck init.sh bin/pds profile.d/pds.sh scripts/*.sh
	@echo "✅ Linting completed"

validate: ## Validate package configuration
	@echo "Validating package configuration..."
	@nfpm validate nfpm.yaml
	@echo "✅ Package configuration is valid"

info: ## Show package information
	@echo "Package Information:"
	@echo "==================="
	@echo "Name: $(PACKAGE_NAME)"
	@echo "Version: $(VERSION)"
	@echo "Architecture: $(ARCH)"
	@echo "Build directory: $(DIST_DIR)"
	@echo "Source functions:"
	@find ../bash -name "*.sh" -type f | wc -l | xargs echo "  Total scripts:"
	@if [ -d ../bash/debian ]; then \
		find ../bash/debian -name "*.sh" -type f | wc -l | xargs echo "  Debian scripts:"; \
		for dir in $$(find ../bash/debian -mindepth 1 -type d 2>/dev/null); do \
			count=$$(find "$$dir" -maxdepth 1 -name "*.sh" -type f | wc -l); \
			if [ "$$count" -gt 0 ]; then \
				echo "    $$(basename $$dir): $$count scripts"; \
			fi; \
		done; \
	fi
	@if [ -d ../bash/common ]; then \
		find ../bash/common -name "*.sh" -type f | wc -l | xargs echo "  Common scripts:"; \
		for dir in $$(find ../bash/common -mindepth 1 -type d 2>/dev/null); do \
			count=$$(find "$$dir" -maxdepth 1 -name "*.sh" -type f | wc -l); \
			if [ "$$count" -gt 0 ]; then \
				echo "    $$(basename $$dir): $$count scripts"; \
			fi; \
		done; \
	fi
