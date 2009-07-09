
# Some BSD compatibility declarations
# TODO double-check ARCHIVE, PREFIX
.ALLSRC = $^
.ARCHIVE = $!
.IMPSRC = $<
.MEMBER = $%
.OODATE = $?
.PREFIX = $*
.TARGET = $@
.CURDIR = ${CURDIR}
