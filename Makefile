ORG_FILES := $(filter-out org/posts/template.org,$(wildcard org/posts/*.org))
MDX_FILES := $(patsubst org/posts/%.org,src/content/blog/%.mdx,$(ORG_FILES))

.PHONY: posts dev build preview clean eval-babel test test-script test-dist

posts: $(MDX_FILES)

src/content/blog/%.mdx: org/posts/%.org scripts/org-to-mdx.sh
	@./scripts/org-to-mdx.sh $< $@

dev: posts
	pnpm dev

build: posts
	pnpm build

preview: build
	pnpm preview

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
