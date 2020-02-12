#!/usr/bin/make -f
#
# Makefile for robotfindskitten
# Copyright 2011-2014 Damian Yerrick
#
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.
#

# These are used in the title of the NES program and the zip file.
title:= robotfindskitten

# I started this project on Sun 2014-07-07 (base: 16258)
# but took a 100 day break to give forum.nesdev.com users
# time to evaluate Scoth42's implementation.
# After 100 days, I posted my own and corrected the
# effective starting point to 16358.
# I abandoned this after day 9; begin normal version numbers at 0.10
#CURDAY := $(shell echo $$(( ($$(date -d 'now' '+%s') / 86400) - 16358 )))
#version := day$(CURDAY)

# But I need to split the major and minor version into ints so I can
# pass them to ca65
major_version := 0
minor_version := 10

version := $(major_version).$(minor_version)

nkifiles = fixed default drugs

# Assembly language files that make up the PRG ROM
align_sensitive_modules := vwf7 random
game_modules := \
  main bg title nki nkidata
lib_modules := vwf_draw ppuclear pads bcd
audio_modules := 
objlist := $(align_sensitive_modules) $(game_modules) \
  $(lib_modules) $(audio_modules)

AS65 = ca65
LD65 = ld65
CFLAGS65 = -DUSE_DAS=1 -g -DMAJOR_VERSION=$(major_version) -DMINOR_VERSION=$(minor_version)
objdir = obj/nes
srcdir = src
imgdir = tilesets

#EMU := "/C/Program Files/Nintendulator/Nintendulator.exe"
EMU := fceux
# other options for EMU are start (Windows) or gnome-open (GNOME)

# The by Johnathan Roatch is written in C.  Compile it.
CC := gcc
CFLAGS := -std=gnu99 -Wall -Wextra -DNDEBUG -Os

# Windows needs .exe suffixed to the names of executables; UNIX does
# not.  Also the Windows Python installer puts py.exe in the path,
# but not python3.exe, which confuses MSYS Make.  COMSPEC will be set
# to the name of the shell on Windows and not defined on UNIX.
ifdef COMSPEC
DOTEXE:=.exe
PY:=py -3
else
DOTEXE:=
PY:=python3
endif

.PHONY: run debug all dist zip clean

run: $(title).nes
	$(EMU) $<
debug: $(title).nes
	$(DEBUGEMU) $<
debug2: $(title).nes
	$(DEBUGEMU2) $<
all: $(title).nes
dist: zip
zip: $(title)-$(version).zip
clean:
	-rm $(objdir)/*.o $(objdir)/*.chr $(objdir)/*.s
	-rm map.txt tools/dte$(DOTEXE)
ctools:
	tools/dte$(DOTEXE)

# Rule to create or update the distribution zipfile by adding all
# files listed in zip.in.  Actually the zipfile depends on every
# single file in zip.in, but currently we use changes to the compiled
# program, makefile, and README as a heuristic for when something was
# changed.  It won't see changes to docs or tools, but usually when
# docs changes, README also changes, and when tools changes, the
# makefile changes.
$(title)-$(version).zip: zip.in $(title).nes README.md CHANGES.txt $(objdir)/index.txt
	$(PY) tools/zipup.py $< $(title)-$(version) -o $@

# Build zip.in from the list of files in the Git tree
zip.in:
	git ls-files | grep -e "^[^.]" > $@
	echo $(title).nes >> $@
	echo zip.in >> $@

# Force creation of empty folder
$(objdir)/index.txt: makefile
	echo "Files produced by build tools go here." > $@

# Rules for PRG ROM

objlistntsc := $(foreach o,$(objlist),$(objdir)/$(o).o)

map.txt $(title).nes: rfk.x $(objlistntsc)
	$(LD65) -o $(title).nes -m map.txt --dbgfile $(title).dbg -C $^

$(objdir)/%.o: $(srcdir)/%.s $(srcdir)/nes.inc $(srcdir)/rfk.inc $(srcdir)/mbyt.inc
	$(AS65) $(CFLAGS65) $< -o $@

$(objdir)/%.o: $(objdir)/%.s
	$(AS65) $(CFLAGS65) $< -o $@

# .incbin dependencies

# title.s depends on instructions
# it also depends on the version number
$(objdir)/title.o: $(srcdir)/uctions1.txt makefile

# Graphics conversion

$(objdir)/%.s: tools/vwfbuild.py tilesets/%.png
	$(PY) $^ $@

# NKI conversion

nkipaths := $(foreach o,$(nkifiles),$(srcdir)/$(o).nki)

$(objdir)/nkidata.s: tools/nkiconvert.py tilesets/vwf7.png tools/dte$(DOTEXE) $(nkipaths)
	$(PY) $< --wrap-width 112 --wrap-font tilesets/vwf7.png \
	$(nkipaths) > $@

tools/dte$(DOTEXE): tools/dte.c
	$(CC) -static $(CFLAGS) -o $@ $^
