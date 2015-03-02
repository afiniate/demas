NAME:=demas
LICENSE:="OSI Approved :: Apache Software License v2.0"
AUTHOR:="Afiniate, Inc."
HOMEPAGE:="https://github.com/afiniate/demas"

DEV_REPO:="git@github.com:afiniate/demas.git"
BUG_REPORTS:="https://github.com/afiniate/demas/issues"

DESC:=""

BUILD_DEPS:=vrt
DEPS:=core async async_unix async_shell cohttp cohttp.async sexplib ouija

vrt.mk:
	vrt prj gen-mk

-include vrt.mk
