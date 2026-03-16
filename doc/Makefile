SRC_DIR=	../src/zulipcli

.PHONY: all
all: zulipcli.pdf

zulipcli.pdf: zulipcli.tex preamble.tex
zulipcli.pdf: ${SRC_DIR}/init.tex
zulipcli.pdf: ${SRC_DIR}/cli.tex

${SRC_DIR}/%.tex:
	${MAKE} -C ${SRC_DIR} $(notdir $@)

.PHONY: clean
clean:
	${RM} zulipcli.pdf

INCLUDE_MAKEFILES=../makefiles
include ${INCLUDE_MAKEFILES}/tex.mk
