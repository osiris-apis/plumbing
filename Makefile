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

# https://github.com/osiris-apis/plumbing/pkgs/container/osiris-mdbook
IMG_MDBOOK		?= ghcr.io/osiris-apis/osiris-mdbook:latest
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
# Common Functions
#

# Replace spaces with other characters in a list.
F_REPLACE_SPACE		= $(subst $(eval ) ,$2,$1)

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
	@echo "    book-build:         Build the mdbook-based book"
	@echo "    book-serve:         Serve the mdbook-based book"
	@echo "    book-test:          Run the book test suite"
	@echo
	@echo "    deploy-book:        Deploy the book"
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
# Target: book-*
#

.PHONY: book-build
book-build: $(BUILDDIR)/book/
	$(DOCKER_RUN_SELF) \
		--init \
		--volume "$(abspath $(BUILDDIR)):/srv/build" \
		--volume "$(abspath $(SRCDIR)):/srv/src" \
		"$(IMG_MDBOOK)" \
			build \
			--dest-dir "/srv/build/book" \
			"/srv/src/lib/book"

.PHONY: book-serve
book-serve: $(BUILDDIR)/book/
	$(DOCKER_RUN_SELF) \
		--init \
		--publish "1111:1111" \
		--volume "$(abspath $(BUILDDIR)):/srv/build" \
		--volume "$(abspath $(SRCDIR)):/srv/src" \
		"$(IMG_MDBOOK)" \
			serve \
			--dest-dir "/srv/build/book" \
			--hostname "0.0.0.0" \
			--port 1111 \
			"/srv/src/lib/book"

.PHONY: book-test
book-test:
	test -d "$(BUILDDIR)/book"

#
# Target: deploy-*
#

.PHONY: deploy-verify-env
deploy-verify-env:
	test ! -z "$${OSRS_DEPLOY_HOSTNAME}"
	test ! -z "$${OSRS_DEPLOY_USERNAME}"
	test ! -z "$${OSRS_DEPLOY_PASSWORD}"

.PHONY: deploy-book
deploy-book: deploy-verify-env
	SSHPASS="$${OSRS_DEPLOY_PASSWORD}" \
		$(SSHPASS_E) \
			$(SFTP_PUSH) \
				-b <(printf \
					"%s\n%s\n%s\n" \
					"-mkdir /public/lib" \
					"-mkdir /public/lib/book" \
					"put -R \"$(BUILDDIR)/book/.\" /public/lib/book" \
				) \
				"$${OSRS_DEPLOY_USERNAME}@$${OSRS_DEPLOY_HOSTNAME}"

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

WEB_TOPLEVEL = \
	s \
	w \
	404.html \
	index.html \
	robots.txt \
	sitemap.xml

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
	@# Test existance of the directory.
	test -d "$(BUILDDIR)/web"
	@# Verify that we know exactly what is placed on the root level.
	test "$$(ls "$(BUILDDIR)/web" | sort)" = \
		"$$( \
			printf \
			"$(call F_REPLACE_SPACE,$(sort $(WEB_TOPLEVEL)),\n)\n" \
		)"
