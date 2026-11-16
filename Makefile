SHELL := /bin/bash

.PHONY: help preflight deploy-image status

help:
	@echo "make deploy-image [TAG=<12-char sha>]  Deploy an app image tag to the demo host (default: newest in ECR)"
	@echo "make status                             Read-only snapshot: armed/fixed state, running image, latest build"
	@echo "make preflight                          Verify AWS account and Datadog keys"
	@echo "(break / reset / status: Phase 5)"

preflight:
	@./scripts/preflight.sh

deploy-image: preflight
	@./scripts/deploy-image.sh $(TAG)

status:
	@./scripts/status.sh
