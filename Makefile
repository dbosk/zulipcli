SUBDIR_GOALS=	all clean distclean
SUBDIR+=	src/zulipcli
SUBDIR+=	tests
SUBDIR+=	doc

version=$(shell sed -n 's/^ *version *= *\"\([^\"]\+\)\"/\1/p' pyproject.toml)

.PHONY: all
all: compile

.PHONY: compile
compile:
	${MAKE} -C src/zulipcli all
	poetry build

.PHONY: test
test: compile
	${MAKE} -C tests all
	poetry run pytest tests/

.PHONY: install
install: compile
	pipx install .

.PHONY: publish
publish: publish-pypi publish-github

.PHONY: publish-pypi
publish-pypi: compile
	poetry publish

.PHONY: publish-github
publish-github: doc/zulipcli.pdf
	git push
	gh release create -t v${version} v${version} doc/zulipcli.pdf

.PHONY: clean distclean
clean:
distclean:
	${RM} -Rf dist *.egg-info src/*.egg-info

INCLUDE_MAKEFILES=makefiles
include ${INCLUDE_MAKEFILES}/subdir.mk
