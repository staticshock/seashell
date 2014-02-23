# Copyright (c) 2013, Anton Backer <olegov@gmail.com>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
# REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
# INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.

SHELL = /bin/bash

SRC_ROOT = $(CURDIR)
DST_ROOT = $(HOME)
PATCH_ROOT = $(CURDIR)/patches

# By default, export all files or directories starting with a dot, minus git
# files.
EXPORT = $(shell find "$(SRC_ROOT)" -mindepth 1 -maxdepth 1 -name '.*' $(patsubst %,-not -name '%',$(NO_EXPORT))) \
		 $(shell find $(addprefix "$(SRC_ROOT)"/,$(EXPORT_CONTENT)) -mindepth 1 -type f 2>/dev/null) \
		 $(wildcard $(addprefix $(SRC_ROOT)/,$(EXPORT_APPEND)))

EXPORT_APPEND =
EXPORT_CONTENT = .ssh
NO_EXPORT = .git* .mailmap *.pid $(EXPORT_CONTENT)

# The global .gitignore conflicts with the repo's own .gitignore, so the global
# one can be stored in the repo as .gitignore.export.
EXPLICIT_EXPORT = $(shell find "$(SRC_ROOT)" -name '*.export')

AUTHORIZED_KEYS = $(shell find "$(SRC_ROOT)"/.ssh -mindepth 1 -type f -name '*.pub' 2>/dev/null)

REMOTE_NAME = origin
REMOTE_BRANCH = $(shell git symbolic-ref HEAD)

export_dst = \
	$(patsubst $(SRC_ROOT)/%,$(DST_ROOT)/%,$(filter $(SRC_ROOT)/%,$(EXPORT))) \
	$(patsubst %,$(DST_ROOT)/%,$(filter-out $(SRC_ROOT)/%,$(EXPORT)))

explicit_export_dst = \
	$(patsubst $(SRC_ROOT)/%.export,$(DST_ROOT)/%,$(filter $(SRC_ROOT)/%,$(EXPLICIT_EXPORT))) \
	$(patsubst %.export,$(DST_ROOT)/%,$(filter-out $(SRC_ROOT)/%,$(EXPLICIT_EXPORT)))

define mkdir_and_export_target
@mkdir -p "$$(dirname "$@")"
$(export_target)
endef

ifeq ($(RSYNC),y)
export_target = @[[ -d "$<" ]] && sl='/' || sl=''; rsync -ai --del "$<$$sl" "$@"
else
ifeq ($(COPY),y)
export_target = @cp -rfv "$<" "$@"
else
# Use '-T' option of GNU coreutils `ln` if available to prevent interpreting
# the target argument of `ln` as a directory into which to link a regular
# file (i.e., `ln -s FILE FILE` and `ln -s DIR DIR` are allowed, but
# `ln -s FILE DIR` is not). GNU `ln` might be installed as `gln` under
# non-Linux systems.
export_target = @if ln --version 2>/dev/null | grep -qe'GNU coreutils'; then \
		ln -sfTv "$<" "$@"; \
		elif gln --version 2>/dev/null | grep -qe'GNU coreutils'; then \
		gln -sfTv "$<" "$@"; \
		elif [ -f "$<" ] && [ -d "$@" ]; then \
		echo "$@ must be a regular file if $< is" 1>&2; \
		else ln -sfv "$<" "$@"; fi
endif
endif

.DEFAULT_GOAL = init

# Supplementary Makefile
-include Makefile.conf

.PHONY : init
init :
	@git submodule update --init
	@[[ ! -d $(PATCH_ROOT) ]] || \
		while IFS= read -r -d $$'\0' patch; do ( \
			cd "$(SRC_ROOT)/$${patch%/*}"; \
			patch -p1 -N -r - < "$(PATCH_ROOT)/$$patch" || true \
		); done < <(cd "$(PATCH_ROOT)"; find -type f -print0 2>/dev/null)
	$(init_append)

.PHONY : install
install : $(export_dst) $(explicit_export_dst) $(AUTHORIZED_KEYS)
	$(install_append)

$(DST_ROOT)/% : $(SRC_ROOT)/%
	$(mkdir_and_export_target)

$(explicit_export_dst) : $(DST_ROOT)/% : $(SRC_ROOT)/%.export
	$(mkdir_and_export_target)

# Add keys to the authorized key list
ifneq ($(AUTHORIZED_KEYS),)
install : $(DST_ROOT)/.ssh/authorized_keys
# Force it to re-run every time
.PHONY : $(DST_ROOT)/.ssh/authorized_keys
$(DST_ROOT)/.ssh/authorized_keys : | $(DST_ROOT)/.ssh
	@for key in $(patsubst %,"%",$(AUTHORIZED_KEYS)); do \
		grep -q "$$(cat $$key)" "$@" 2>/dev/null || cat "$$key" >> "$@"; \
	done
endif

# If .ssh is present, make sure the destination .ssh directory exists with
# proper permissions
ifneq ($(wildcard $(SRC_ROOT)/.ssh),)
install : $(DST_ROOT)/.ssh
endif
.PHONY: $(DST_ROOT)/.ssh
$(DST_ROOT)/.ssh :
	@install -d -m 700 "$@"

.PHONY : import
import :
	@[[ -n "$$(which rsync)" ]] && method=RSYNC || method=COPY; \
		$(MAKE) install SRC_ROOT=$(DST_ROOT) DST_ROOT=$(SRC_ROOT) EXPLICIT_EXPORT= $$method=y

.PHONY : uninstall
uninstall :
	@rm $(patsubst %,\"%\",$(export_dst))
	@rm $(patsubst %,\"%\",$(explicit_export_dst))

.PHONY : update
update :
	@before_stash="$$(git stash list | wc -l)"; \
	git stash; \
	after_stash="$$(git stash list | wc -l)"; \
	git checkout master; \
	git pull --rebase $(REMOTE_NAME) $(REMOTE_BRANCH); \
	[[ $$before_stash = $$after_stash ]] || git stash pop; \
	make && make install

.PHONY : update-submodules
update-submodules :
	@git submodule foreach git pull origin master
