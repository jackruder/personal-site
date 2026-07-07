ORG_FILES := $(filter-out org/posts/template.org,$(wildcard org/posts/*.org))
MDX_FILES := $(patsubst org/posts/%.org,src/content/blog/%.mdx,$(ORG_FILES))

-include .deploy.env

DEPLOY_USER ?= deploy
DEPLOY_HOST ?=
DEPLOY_PATH ?= /var/www/personal-site/
DEPLOY_KEY  ?= ./deploy_key

# Use pnpm directly if it's on PATH; otherwise fall back to the flake's devShell.
# Override with `make PNPM=pnpm ...` to force the direct binary.
PNPM ?= $(shell command -v pnpm >/dev/null 2>&1 && echo pnpm || echo nix develop --command pnpm)
RSYNC ?= $(shell command -v rsync >/dev/null 2>&1 && echo rsync || echo nix develop --command rsync)

.PHONY: posts dev build preview clean eval-babel test test-script test-dist deploy

posts: $(MDX_FILES)

src/content/blog/%.mdx: org/posts/%.org scripts/org-to-mdx.sh
	@./scripts/org-to-mdx.sh $< $@

dev: posts
	$(PNPM) dev

build: posts
	$(PNPM) build

preview: build
	$(PNPM) preview

eval-babel:
	@for f in $(ORG_FILES); do \
	  if grep -q ':results' "$$f"; then \
	    echo "evaluating $$f"; \
	    emacs --batch --load scripts/eval-babel.el "$$f"; \
	  fi; \
	done

clean:
	rm -f src/content/blog/*.mdx
	rm -rf dist/

test: test-script test-dist

test-script:
	@./tests/org-to-mdx.test.sh

test-dist: build
	@./tests/dist.test.sh

deploy: build
	@test -n "$(DEPLOY_HOST)" || { \
	  echo "DEPLOY_HOST is unset. Create .deploy.env with DEPLOY_HOST=<vm-ip>, or pass inline:" >&2; \
	  echo "  DEPLOY_HOST=10.0.0.1 make deploy" >&2; \
	  exit 1; \
	}
	$(RSYNC) -avz --delete -e "ssh -i $(DEPLOY_KEY)" ./dist/ $(DEPLOY_USER)@$(DEPLOY_HOST):$(DEPLOY_PATH)
