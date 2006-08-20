# file: Makefile
#
# makefile for dvb's QuickTime Tools
#
# a set of handy QuickTime command line tools
# 2003 March
# 2006 March...
#
# REQUIREMENTS:
#
#   You must have the Apple Developer Tools installed, and
#   have /Developer/Tools in your path.
#   This is for Rez and CpMac.
#
# ex:set tabstop=4:
# ex:set noexpandtab:

#
# what I learned from internet!
# sudo fixPrecomps -- fix the precompiled headers!
#

EE = echo `date` ---
E = @$(EE)
LIBS = \
	-framework QuickTime \
	-framework Carbon \
	-framework CoreServices \
	-framework Cocoa

# where things come from...
SRC = ./src
TOOLS = ./tools


# where things go to.
BUILD = ./build
OBJ = ./obj
MAN = $(BUILD)/man
HTML = $(BUILD)/html
APP = $(BUILD)/app
REL = qt_tools
SITE = ./qt_tools_site

# copy of the sources, for distribution
SOURCEDIST = ./sourcedist

UTILS = \
	qtc_utils.c

UTILS_OBJECTS = \
	$(OBJ)/qtc_utils.o

INCLUDES = $(SRC)/qtc_utils.h $(OBJ)/qtc_manpages.h $(SRC)/version.h

SUITE = qt_export qt_info qt_thing qt_atom qt_proofsheet

MANPAGES = \
	$(SRC)/qt_atom.pl \
	$(SRC)/qt_export.pl \
	$(SRC)/qt_info.pl \
	$(SRC)/qt_thing.pl \
	$(SRC)/qt_tools.pl \
	$(SRC)/qt_proofsheet.pl

#
# The default build target is "suite" but done quietly, so only
# the pretty status gets shown.
#
# make all will still do a conventional noisy build
#

quietly :
	make -s suite

suite : $(SUITE)

help :
	@echo . Makefile Help
	@echo .
	@echo . The main targets are:
	@echo .
	@echo .        suite -- build only the tools binaries (default make target)
	@echo .          all -- all the software and manpages, bumps the build number
	@echo .      release -- bundles it all into a named folder
	@echo .

all : bump_build_number $(SUITE) $(UTILS_OBJECTS)

release : all source_to_release runtests
	@ver=`cat $(SRC)/version.h | $(TOOLS)/spew_version.pl` ;\
	dat=`cat $(SRC)/version.h | $(TOOLS)/spew_version.pl 1` ;\
	rel=$(REL)_$$ver ;\
	$(EE) Packaging $$rel/ ;\
	rm -rf $$rel ;\
	mkdir $$rel ;\
	mkdir -p $$rel/pieces/bin ;\
	CpMac -r $(APP)/* $$rel/pieces/bin/ ;\
	CpMac -r $(MAN) $$rel/pieces/ ;\
	CpMac -r $(SOURCEDIST) $$rel ;\
	cat install.sh | sed -e "s/__version__/$$ver $$dat/g" > $$rel/install.sh ;\
	chmod +x $$rel/install.sh ;\
	echo "Version $$ver" > $$rel/README.txt ;\
	echo " " >> $$rel/README.txt ;\
	pod2text $(SRC)/qt_tools.pl >> $$rel/README.txt ;\
	hdiutil create -fs HFS+ -volname $$rel -srcfolder $$rel $$rel.dmg ;\
	tar czf $$rel.tgz $$rel ;\
	site=$(SITE)_$$ver ;\
	mkdir $$site ;\
	mv $$rel $$site/qt_tools ;\
	mv $$rel.tgz $$site/qt_tools.tgz ;\
	mv $$rel.dmg $$site/qt_tools.dmg ;\
	v=`$(TOOLS)/spew_version.pl 2 < $(SRC)/version.h` ;\
	b=`$(TOOLS)/spew_version.pl 3 < $(SRC)/version.h` ;\
	d=`$(TOOLS)/spew_version.pl 1 < $(SRC)/version.h` ;\
	export PERL5LIB=$(TOOLS) ;\
	mv $(OBJ)/testresults.txt $$site/ ;\
	cp -r ./website/* $$site ;\
	$(TOOLS)/munge_and_move.pl ./website/index.html $$site/index.html v=$$v b=$$b d=$$d ;\
	cp -r $(HTML)/man $$site ;\
	find $$site -name RCS | xargs rm -r


check_site_gen :
	mkdir fakesite ;\
	v=`$(TOOLS)/spew_version.pl 2 < $(SRC)/version.h` ;\
	b=`$(TOOLS)/spew_version.pl 3 < $(SRC)/version.h` ;\
	d=`$(TOOLS)/spew_version.pl 1 < $(SRC)/version.h` ;\
	export PERL5LIB=$(TOOLS) ;\
	mv $(OBJ)/testresults.txt fakesite/ ;\
	cp -r ./website/* fakesite ;\
	$(TOOLS)/munge_and_move.pl ./website/index.html fakesite/index.html v=$$v b=$$b d=$$d ;\
	cp -r $(HTML)/man fakesite



#
# Hooray for hdiutil! 2004.10.05, I finally learn this secret!
# thank you Rich Kilmer and his blog!
#

$(BUILD) :
	$(E) Making $(BUILD) Directory
	@mkdir -p $(BUILD)

$(SOURCEDIST) : $(BUILD)
	$(E) Making $(SOURCEDIST) Directory
	@mkdir -p $(SOURCEDIST)

$(APP) : $(BUILD)
	$(E) Making $(APP) Directory
	@mkdir -p $(APP)

$(OBJ) : $(BUILD)
	$(E) Making $(OBJ) Directory
	@mkdir -p $(OBJ)

$(HTML) : $(BUILD)
	$(E) Making $(HTML) Directory
	@mkdir -p $(HTML)
	@mkdir -p $(HTML)/man

$(MAN) : $(BUILD)
	$(E) Making $(MAN) Directory
	@mkdir -p $(MAN)
	@mkdir -p $(MAN)/man1

FOLDERS = @make -s $(BUILD) $(APP) $(OBJ) $(MAN) $(SOURCEDIST) $(HTML)

bump_build_number :
	$(E) Bumping build number
	$(TOOLS)/bump_version.pl $(SRC)/version.h k_version_build_number

$(MAN)/man1/%.1 : $(SRC)/%.pl
	pod2man --section=1 --center="dvb's QuickTime Tools `cat $(SRC)/version.h | $(TOOLS)/spew_version.pl`" $< $@

$(HTML)/man/%.html : $(SRC)/%.pl
	$(FOLDERS)
	pod2html $< --title=qt_tools > $@

#
# qtc_manpages.h is a machine-generated header file which contains
# macros for printing man pages.
#
# It happened to be convenient to just lump all the macros
# for all the tools into one file. The macros are long
# strings of printf() this and thats.
#

$(OBJ)/qtc_manpages.h : $(MANPAGES) $(HTML)
	$(FOLDERS)
	$(E) Building Man Pages

	@echo "// `date`" > $(OBJ)/qtc_manpages.h
	@echo "// this is a machine-generated file" >> $(OBJ)/qtc_manpages.h

	@for mp in $(MANPAGES) ;\
	do \
		mp0=`basename $$mp .pl` ;\
		mp1=$$mp0.1 ;\
		echo "#define print_$${mp0}_man \\" >> $(OBJ)/qtc_manpages.h ;\
		pod2text $$mp | $(TOOLS)/text2printf.pl "   printf(" "); \\" >> $(OBJ)/qtc_manpages.h ;\
		echo " " >>qtc_manpages.h ;\
		$(EE) Making $$mp1 ;\
		make -s $(MAN)/man1/$$mp1 ;\
		make -s $(HTML)/man/$$mp0.html ;\
	done

	@echo "// end of file" >> $(OBJ)/qtc_manpages.h



$(OBJ)/%.o : $(SRC)/%.c $(INCLUDES)
	$(FOLDERS)
	$(E) Compiling $<
	@gcc -I. -I$(SRC) -I$(OBJ) -DHOSTNAME=\"`hostname`\" -c $< -o $@

$(APP)/% : $(OBJ)/%.o $(UTILS_OBJECTS)
	$(FOLDERS)
	$(E) Linking $@
	gcc $< $(UTILS_OBJECTS) $(LIBS) -g -o $@
	$(E) Rezzing $@
	@echo "data 'carb' (0) { };" | Rez -a -o $@

qt_atom : $(APP)/qt_atom
	@#$(E) Copying qt_atom
	@#@CpMac $(APP)/qt_atom ./qt_atom

qt_info : $(APP)/qt_info
	@#$(E) Copying qt_info
	@#@CpMac $(APP)/qt_info ./qt_info

qt_proofsheet : $(APP)/qt_proofsheet
	@#$(E) Copying qt_proofsheet
	@#@CpMac $(APP)/qt_proofsheet ./qt_proofsheet

qt_export : $(APP)/qt_export
	@#$(E) Copying qt_export
	@#@CpMac $(APP)/qt_export ./qt_export

qt_thing : $(APP)/qt_thing
	@#$(E) Copying qt_thing
	@#@CpMac $(APP)/qt_thing ./qt_thing

clean :
	$(E) cleaning
	rm -rf $(BUILD) $(OBJ) $(MAN) $(APP) $(SOURCEDIST) $(HTML)

source_to_release : $(SUITE)
	$(FOLDERS)
	$(E) Making src/ Drop
	@cp -rf $(SRC) $(SOURCEDIST)
	@cp -rf $(TOOLS) $(SOURCEDIST)
	@cp -f Makefile $(SOURCEDIST)
	@chmod +w $(SOURCEDIST)/*
	@mkdir $(SOURCEDIST)/testsuite
	@cp testsuite/runtests.pl testsuite/sweep.mov $(SOURCEDIST)/testsuite

runtests : $(SUITE)
	$(E) Running Tests...
	@cd testsuite ; \
		./runtests.pl > ../$(OBJ)/testresults.txt
	$(E) Done with tests

test_qt_proofsheet:
	make -s qt_proofsheet
	qt_proofsheet sweep.mov fo4.jpg
	open fo4.jpg

# end of file