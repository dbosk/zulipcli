# Tests are written in .nw files throughout src/ using chunks named
# "<<test [[modulename.py]]>>". This Makefile automatically discovers
# those chunks and tangles them to tests/unit/test_*.py files.

# Auto-discover test chunks in .nw files
define find_tests
( \
	find ../src -name '*.nw' | xargs grep -l '<<test \[\[.*\.py\]\]>>' | \
		while read file; do \
			chunk=$$(grep -o '<<test \[\[\([^]]*\)\.py\]\]>>' "$$file" | \
			         head -1 | \
			         sed 's/<<test \[\[\(.*\)\.py\]\]>>/\1/'); \
			chunk_safe=$$(echo "$$chunk" | sed 's/ /%20/g'); \
			echo "unit/test_$${chunk_safe}.py:$$file:test%20[[$$chunk_safe.py]]"; \
		done; \
) | sort -u
endef

# Generate build target for each discovered test
define def_target
$(shell echo $1 | cut -d: -f1): $(shell echo $1 | cut -d: -f2)
	@mkdir -p $$(dir $$@)
	notangle -R"$(shell echo $1 | cut -d: -f3 | sed 's/%20/ /g')" $$< | cpif $$@
endef

# Discover all tests
TESTS := $(shell $(find_tests))

# Extract just the test filenames
TEST_MODULES := $(foreach entry,$(TESTS),$(shell echo $(entry) | cut -d: -f1))

.PHONY: all
all: $(TEST_MODULES)

# Generate rules for each test
$(foreach entry,$(TESTS),$(eval $(call def_target,$(entry))))

.PHONY: test
test: all
	${MAKE} -C ../src/zulipcli all
	pytest -v

.PHONY: clean
clean:
	${RM} $(TEST_MODULES)
	${RM} -r .pytest_cache __pycache__ unit/__pycache__
	${RM} -r htmlcov .coverage
