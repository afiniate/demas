NAME:=demas
LICENSE:="OSI Approved :: Apache Software License v2.0"
AUTHOR:="Afiniate, Inc."
HOMEPAGE:="https://github.com/afiniate/demas"

DEV_REPO:="git@github.com:afiniate/demas.git"
BUG_REPORTS:="https://github.com/afiniate/demas/issues"

DESC_FILE:= desc

OCAML_PKG_DEPS := ocaml findlib camlp4
OCAML_DEPS := core sexplib sexplib.syntax async cohttp cohttp.async ouija
DEPS := trv vrt

trv.mk:
	trv build gen-mk

-include trv.mk
