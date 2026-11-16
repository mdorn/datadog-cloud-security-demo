SHELL := /bin/bash

.PHONY: help preflight status deploy-image break reset fix-pr

help:
	@echo "make status                             Read-only snapshot: armed/fixed state, running image, latest build"
	@echo "make break                              Re-arm misconfigs (plan + confirm) and redeploy the vulnerable baseline image"
	@echo "make reset                              break + revert PR restoring vulnerable deps on main + Jira issues to close"
	@echo "make deploy-image [TAG=<12-char sha>]   Deploy an app image tag to the demo host (default: newest in ECR)"
	@echo "make fix-pr DEP=log4j|commons-text|jackson [DRY_RUN=1]   Open a one-line dependency-bump PR"
	@echo "make preflight                          Verify AWS account and Datadog keys"

preflight:
	@./scripts/preflight.sh

status:
	@./scripts/status.sh

deploy-image: preflight
	@./scripts/deploy-image.sh $(TAG)

break:
	@./scripts/break.sh

reset:
	@./scripts/reset.sh

fix-pr:
	@./scripts/fix-pr.sh $(DEP) $(if $(DRY_RUN),--dry-run,)
