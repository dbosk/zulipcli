SUBDIR_GOALS=	all clean distclean
SUBDIR+=	src/zulipcli
SUBDIR+=	tests
SUBDIR+=	doc

.PHONY: all
all: compile

.PHONY: compile
compile:
	${MAKE} -C src/zulipcli all

.PHONY: test
test: compile
	${MAKE} -C tests all
	poetry run pytest tests/

.PHONY: install
install: compile
	python3 -m pip install -e .

.PHONY: clean distclean
clean:
distclean:
	${RM} -Rf dist *.egg-info src/*.egg-info

INCLUDE_MAKEFILES=makefiles
include ${INCLUDE_MAKEFILES}/subdir.mk
