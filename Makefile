#
# Maintenance Makefile
#

# Enforce bash with fatal errors.
SHELL			:= /bin/bash -eo pipefail

# Keep intermediates around on failures for better caching.
.SECONDARY:

# Default build and source directories.
BUILDDIR		?= ./build
SRCDIR			?= .

#
# Build Images
#

# https://github.com/getzola/zola/pkgs/container/zola/versions
IMG_ZOLA		?= ghcr.io/getzola/zola:v0.17.2

#
# Common Commands
#

DOCKER_RUN		= \
	docker \
		run \
		--interactive \
		--rm

DOCKER_RUN_SELF		= \
	$(DOCKER_RUN) \
		--user "$$(id -u):$$(id -g)"

SFTP_PUSH		= \
	sftp \
		-o "BatchMode=no" \
		-o "PreferredAuthentications=password" \
		-o "PubkeyAuthentication=no" \
		-o "StrictHostKeyChecking=no"

SSHPASS_E		= \
	sshpass -e

#
# Target: help
#

.PHONY: help
help:
	@# 80-width marker:
	@#     01234567012345670123456701234567012345670123456701234567012345670123456701234567
	@echo "make [TARGETS...]"
	@echo
	@echo "The following targets are provided by this maintenance makefile:"
	@echo
	@echo "    help:               Print this usage information"
	@echo
	@echo "    deploy-web:         Deploy the website"
	@echo
	@echo "    web-build:          Build the Zola-based website"
	@echo "    web-serve:          Serve the Zola-based website"
	@echo "    web-test:           Run the website test suite"

#
# Target: BUILDDIR
#

$(BUILDDIR)/:
	mkdir -p "$@"

$(BUILDDIR)/%/:
	mkdir -p "$@"

#
# Target: FORCE
#
# Used as alternative to `.PHONY` if the target is not fixed.
#

.PHONY: FORCE
FORCE:

#
# Target: deploy-*
#

.PHONY: deploy-verify-env
deploy-verify-env:
	test ! -z "$${OSRS_DEPLOY_HOSTNAME}"
	test ! -z "$${OSRS_DEPLOY_USERNAME}"
	test ! -z "$${OSRS_DEPLOY_PASSWORD}"

.PHONY: deploy-web
deploy-web: deploy-verify-env
	SSHPASS="$${OSRS_DEPLOY_PASSWORD}" \
		$(SSHPASS_E) \
			$(SFTP_PUSH) \
				-b <(printf \
					"%s\n" \
					"put -R \"$(BUILDDIR)/web/.\" /public/" \
				) \
				"$${OSRS_DEPLOY_USERNAME}@$${OSRS_DEPLOY_HOSTNAME}"

#
# Target: web-*
#

.PHONY: web-build
web-build: $(BUILDDIR)/web/
	$(DOCKER_RUN_SELF) \
		--volume "$(abspath $(BUILDDIR)):/srv/build" \
		--volume "$(abspath $(SRCDIR)):/srv/src" \
		"$(IMG_ZOLA)" \
			--root "/srv/src/lib/web" \
			build \
			--force \
			--output-dir "/srv/build/web"

.PHONY: web-serve
web-serve: $(BUILDDIR)/web/
	$(DOCKER_RUN_SELF) \
		--publish "1111:1111" \
		--volume "$(abspath $(BUILDDIR)):/srv/build" \
		--volume "$(abspath $(SRCDIR)):/srv/src" \
		"$(IMG_ZOLA)" \
			--root "/srv/src/lib/web" \
			serve \
			--interface "0.0.0.0" \
			--output-dir "/srv/build/web"

.PHONY: web-test
web-test:
	test -d "$(BUILDDIR)/web"
