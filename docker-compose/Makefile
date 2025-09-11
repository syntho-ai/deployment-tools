include .env

.PHONY: up

HOST := $(shell echo $(FRONTEND_HOST) | cut -d':' -f1)
up:
	@echo "Checking environment variables..."
	@if [ "$(HOST)" != "$(FRONTEND_DOMAIN)" ]; then \
		echo "❌ FRONTEND_HOST should have the same domain as FRONTEND_DOMAIN"; exit 1; \
	fi
	@echo "✅ All is correct"
	docker compose up -d