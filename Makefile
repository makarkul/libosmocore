# Unified Makefile for libosmocore variants
#
# Usage:
#   make [PLATFORM=linux|freertos] [TARGET]
#
# Platforms:
#   linux    - Build for Linux (default)
#   freertos - Build for FreeRTOS
#
# Targets:
#   help     - Show this help message (default)
#   all      - Full build (libraries + tests)
#   lib      - Build libraries only
#   test     - Run tests (implies lib)
#   clean    - Remove build artifacts
#   shell    - Open development shell (containerized)
#
# Examples:
#   make                           # Show help
#   make PLATFORM=linux all       # Linux build
#   make PLATFORM=freertos lib    # FreeRTOS libraries only
#   make PLATFORM=freertos test   # FreeRTOS build + tests
#   make clean                     # Clean all platforms
#   make PLATFORM=linux clean     # Clean Linux build only

# Configuration
PLATFORM ?= linux
ROOT_DIR := $(CURDIR)
BUILD_ROOT := $(ROOT_DIR)/build
LINUX_BUILD_DIR := $(BUILD_ROOT)/linux
FREERTOS_BUILD_DIR := $(BUILD_ROOT)/freertos

# Validate platform
ifeq ($(filter $(PLATFORM),linux freertos),)
$(error Unsupported platform: $(PLATFORM). Use linux or freertos)
endif

# Default target
.DEFAULT_GOAL := help

# Docker compose commands
DOCKER_COMPOSE := docker compose

# Help target (default)
.PHONY: help
help:
	@echo "Libosmocore Build System"
	@echo "========================"
	@echo ""
	@echo "Usage: make [PLATFORM=linux|freertos] [TARGET]"
	@echo ""
	@echo "Platforms:"
	@echo "  linux    - Build for Linux (default)"
	@echo "  freertos - Build for FreeRTOS"
	@echo ""
	@echo "Targets:"
	@echo "  help     - Show this help message (default)"
	@echo "  all      - Full build (libraries + tests)"
	@echo "  lib      - Build libraries only"
	@echo "  test     - Run tests (implies lib)"
	@echo "  clean    - Remove build artifacts"
	@echo "  shell    - Open development shell (containerized)"
	@echo ""
	@echo "Examples:"
	@echo "  make                           # Show this help"
	@echo "  make PLATFORM=linux all       # Linux build"
	@echo "  make PLATFORM=freertos lib    # FreeRTOS libraries only"
	@echo "  make PLATFORM=freertos test   # FreeRTOS build + tests"
	@echo "  make clean                     # Clean all platforms"
	@echo "  make PLATFORM=linux clean     # Clean Linux build only"

# Platform-specific targets
ifeq ($(PLATFORM),freertos)

.PHONY: all lib test clean shell
all: check-docker-compose
	@echo "[freertos] Full build with tests"
	$(DOCKER_COMPOSE) run --rm build

lib: check-docker-compose
	@echo "[freertos] Libraries only build"
	$(DOCKER_COMPOSE) run --rm build

test: check-docker-compose
	@echo "[freertos] Build and run tests"
	$(DOCKER_COMPOSE) run --rm build

clean:
	@echo "[freertos] Cleaning build directory"
	rm -rf $(FREERTOS_BUILD_DIR)

shell: check-docker-compose
	@echo "[freertos] Opening development shell"
	$(DOCKER_COMPOSE) run --rm shell

check-docker-compose:
	@if [ ! -f "$(ROOT_DIR)/docker-compose.yml" ]; then \
		echo "Error: docker-compose.yml not found"; \
		exit 1; \
	fi

else ifeq ($(PLATFORM),linux)

.PHONY: all lib test clean shell
all: check-docker-compose
	@echo "[linux] Full build"
	$(DOCKER_COMPOSE) run --rm linux bash -lc "make -f /workspace/Makefile linux-build-all"

lib: check-docker-compose
	@echo "[linux] Libraries only build"
	$(DOCKER_COMPOSE) run --rm linux bash -lc "make -f /workspace/Makefile linux-build-lib"

test: check-docker-compose
	@echo "[linux] Build and run tests"
	$(DOCKER_COMPOSE) run --rm linux bash -lc "make -f /workspace/Makefile linux-build-test"

clean:
	@echo "[linux] Cleaning build directory"
	rm -rf $(LINUX_BUILD_DIR)

shell: check-docker-compose
	@echo "[linux] Opening development shell"
	$(DOCKER_COMPOSE) run --rm linux-shell

check-docker-compose:
	@if [ ! -f "$(ROOT_DIR)/docker-compose.yml" ]; then \
		echo "Error: docker-compose.yml not found"; \
		exit 1; \
	fi

# Internal Linux build targets (run inside container)
.PHONY: linux-build-all linux-build-lib linux-build-test
linux-build-all: linux-configure
	@echo "[linux] Building libraries"
	cd $(LINUX_BUILD_DIR) && make -j$$(nproc)

linux-build-lib: linux-configure
	@echo "[linux] Building libraries only"
	cd $(LINUX_BUILD_DIR) && make -j$$(nproc)

linux-build-test: linux-build-lib
	@echo "[linux] Running tests"
	cd $(LINUX_BUILD_DIR) && make check

linux-configure:
	@echo "[linux] Configuring build"
	mkdir -p $(LINUX_BUILD_DIR)
	cd $(ROOT_DIR) && autoreconf -fi
	cd $(LINUX_BUILD_DIR) && \
		if [ ! -f Makefile ] || [ -n "$(LINUX_EXTRA_FLAGS)" ]; then \
			$(ROOT_DIR)/configure $(LINUX_EXTRA_FLAGS); \
		fi

endif

# Platform-independent clean target
.PHONY: clean-all
clean-all:
	@echo "[all] Cleaning all build directories"
	rm -rf $(BUILD_ROOT)

# Legacy migration
.PHONY: migrate-legacy-dirs
migrate-legacy-dirs:
	@if [ -d "$(ROOT_DIR)/build-freertos" ] && [ ! -d "$(FREERTOS_BUILD_DIR)" ]; then \
		echo "Migrating legacy build-freertos directory"; \
		mkdir -p $(BUILD_ROOT); \
		mv $(ROOT_DIR)/build-freertos $(FREERTOS_BUILD_DIR); \
	fi
	@if [ -d "$(ROOT_DIR)/build-linux" ] && [ ! -d "$(LINUX_BUILD_DIR)" ]; then \
		echo "Migrating legacy build-linux directory"; \
		mkdir -p $(BUILD_ROOT); \
		mv $(ROOT_DIR)/build-linux $(LINUX_BUILD_DIR); \
	fi

# Development targets
.PHONY: status
status:
	@echo "Platform: $(PLATFORM)"
	@echo "Build root: $(BUILD_ROOT)"
	@echo "Linux build dir: $(LINUX_BUILD_DIR)"
	@echo "FreeRTOS build dir: $(FREERTOS_BUILD_DIR)"
	@echo ""
	@echo "Build directory status:"
	@if [ -d "$(LINUX_BUILD_DIR)" ]; then \
		echo "  Linux: exists ($$(du -sh $(LINUX_BUILD_DIR) 2>/dev/null | cut -f1))"; \
	else \
		echo "  Linux: not built"; \
	fi
	@if [ -d "$(FREERTOS_BUILD_DIR)" ]; then \
		echo "  FreeRTOS: exists ($$(du -sh $(FREERTOS_BUILD_DIR) 2>/dev/null | cut -f1))"; \
	else \
		echo "  FreeRTOS: not built"; \
	fi