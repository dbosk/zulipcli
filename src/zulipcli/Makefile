MODULES+=	__init__.py init.tex
MODULES+=	cli.py cli.tex

.PHONY: all
all: ${MODULES}

__init__.py: init.nw
	${NOTANGLE.py}

cli.py: cli.nw
cli.tex: cli.nw

.PHONY: clean
clean:
	${RM} ${MODULES}

INCLUDE_MAKEFILES=../../makefiles
include ${INCLUDE_MAKEFILES}/noweb.mk
