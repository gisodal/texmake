# ------------------------------------------------------------------------------
# Set main file to compile
# ------------------------------------------------------------------------------

TEXFILE =

# ------------------------------------------------------------------------------
# Determine main file to compile
# ------------------------------------------------------------------------------

ifneq ($(firstword $(MAKECMDGOALS)),help)
$(eval $(ARGS):;@:)

    ifeq ($(TEXFILE),)
	    TEXFILE := $(shell find . -mindepth 1 -maxdepth 1 -type f -name "*.tex" -printf '%P ')
        ifeq ($(shell echo $(TEXFILE) | wc -w),0)
            $(error No tex files in this directory)
        endif
	    TEXFILE := $(shell echo $(TEXFILE) \
	    	| xargs grep -r -H "documentclass" -- \
	    	| cut -d: -f1 | sort | uniq)
        MATCHES = $(shell echo $(TEXFILE) | wc -w)

        ifeq ($(shell test $(MATCHES) -eq 1; echo $$?),0)
            TEXFILE := $(basename $(TEXFILE))
        else
            $(error Cannot determine main file to compile ($(MATCHES) eligibles). Set variable 'TEXFILE' explicitly)
        endif
    else
        ifneq ($(shell test -f $(TEXFILE); echo $$?),0)
            $(error Specified TEXFILE ('$(TEXFILE)') does not exist)
        endif
    endif
endif

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------

recursive_wildcard=$(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call recursive_wildcard,$d/,$2))
wildcarddir=$(shell find $1 -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
recursive_wildcarddir=$(shell find $1 -mindepth 1 -type d 2>/dev/null)

# ------------------------------------------------------------------------------
# Environment
# ------------------------------------------------------------------------------

export max_print_line=10000
export error_line=254
export half_error_line=238

MAIN       = $(basename $(TEXFILE))
SHELL      = /bin/bash

DIR  	   = $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
BIB        = $(DIR)/bib
TIKZDIR    = $(DIR)/tikz
BUILDDIR   = $(DIR)/build
ARCHIVEDIR = $(DIR)/archive
STYLE      = $(DIR)/style
PACKAGE    = $(DIR)/packages
STYLES     = $(STYLE) $(call recursive_wildcarddir,$(STYLE))
PACKAGES   = $(PACKAGE) $(call recursive_wildcarddir,$(PACKAGE))

INCLUDE    = $(DIR) $(STYLES) $(PACKAGES) $(LATEX_INCLUDE_PATH)
override   LATEX_INCLUDE_PATH := $(subst $(subst ,, ),:,$(strip $(INCLUDE)))

TEXFLAGS   = -shell-escape -halt-on-error -file-line-error -interaction=nonstopmode -output-directory="$(BUILDDIR)" -recorder
LATEX 	   = TEXINPUTS="$(LATEX_INCLUDE_PATH):$(TEXINPUTS)" pdflatex $(TEXFLAGS)
IBIBS      = $(wildcard $(DIR)/bib/*.bib) $(wildcard $(DIR)/*.bib)
OBIBS      = $(addprefix $(BUILDDIR)/, $(notdir $(IBIBS)))
BIBTEX     = bibtex
PDFVIEWER  = evince
BIBTOOL    = bibtool -s -d -x

# ------------------------------------------------------------------------------
# Git commands
# ------------------------------------------------------------------------------

GITAVAILABLE := $(shell command -v git 2> /dev/null)
ifdef GITAVAILABLE

GITLOCATION = $(shell git rev-parse --show-toplevel 2> /dev/null)
ifeq ($(GITLOCATION),$(DIR))
GITBRANCH = $(shell git rev-parse --abbrev-ref HEAD 2> /dev/null)
GITCOMMIT = $(shell git rev-list --count HEAD 2> /dev/null)
GITDATE = $(shell git show -s --format=%cd --date=local HEAD 2> /dev/null)
GITUSER = $(shell git config user.name)
COMPILEDATE = $(shell date +'%a %b %d %H:%M:%S %Y')
$(shell echo -e '\
\\newcommand{\\gitbranch}{$(GITBRANCH)}\n\
\\newcommand{\\gitcommit}{$(GITCOMMIT)}\n\
\\newcommand{\\gitdate}{$(GITDATE)}\n\
\\newcommand{\\gituser}{$(GITUSER)}\n\
\\newcommand{\\compiledate}{$(COMPILEDATE)}\
' > .version)
endif
endif

# ------------------------------------------------------------------------------
# Rules
# ------------------------------------------------------------------------------

.PHONY: $(MAIN) clean pdf draft bibtex bib plots diagrams view all archive ls

$(MAIN): pdf

pdf: $(MAIN).pdf

bibtex: $(BUILDDIR)/$(MAIN).bbl $(OBIBS) | $(BUILDDIR)

all:
	$(MAKE) pdf
	$(MAKE) bibtex
	$(MAKE) pdf
	$(MAKE) pdf

bib: force $(filter-out %$(MAIN).export.bib,$(IBIBS)) | $(BIB)
	@$(BIBTOOL) $(BUILDDIR)/$(MAIN).aux $(IBIBS) 2>/dev/null > $(BIB)/$(MAIN).export.bib
	@echo "$(BIB)/$(MAIN).export.bib created.."

$(MAIN).pdf: force | $(BUILDDIR) $(TIKZDIR)
	@$(LATEX) $(DIR)/$(MAIN).tex
	@cp $(BUILDDIR)/$(MAIN).pdf $(DIR)/

draft: force | $(BUILDDIR) $(TIKZDIR)
	@$(LATEX) "\def\isdraft{1} \input{$(DIR)/$(MAIN).tex}"
	@cp $(BUILDDIR)/$(MAIN).pdf $(DIR)/

$(BUILDDIR)/$(MAIN).aux: pdf

$(foreach bibfile,$(IBIBS),$(eval $(addprefix $(BUILDDIR)/,$(notdir $(bibfile))): $(bibfile);	@cp $$< $$@))

$(BUILDDIR)/$(MAIN).bbl: force $(OBIBS) | $(BUILDDIR)
	@cd $(BUILDDIR); $(BIBTEX) $(MAIN); \
	for BIB in $$(find . -name '*-blx.aux'); do $(BIBTEX) $$BIB; done;

$(BUILDDIR):
	@mkdir -p "$(BUILDDIR)"

$(TIKZDIR):
	@mkdir -p "$(TIKZDIR)"

$(ARCHIVEDIR):
	@mkdir -p "$(ARCHIVEDIR)"

$(BIB):
	@mkdir -p "$(BIB)"

plots: PLOTS = $(call recursive_wildcard,$(DIR)/plots,*.tex)
plots:
	sed -i 's:\\begin{tikzpicture}\[gnuplot\]:\\begin{tikzpicture}[gnuplot,scale=\\tikzscale]:g' $(PLOTS)

diagrams: DIAGRAMS = $(call recursive_wildcard,$(DIR)/diagrams,*.tex)
diagrams:
	sed -i 's:\\ensuremath{\\backslash}:\\:g' $(DIAGRAMS)
	sed -i 's:\\begin{tikzpicture}:\\begin{tikzpicture}[scale=\\tikzscale]:g' $(DIAGRAMS)

clean:
	@rm -rf "$(BUILDDIR)"
	@rm -f $(MAIN).{log,spl,fls,aux,bbl,blg}

ifeq ($(firstword $(MAKECMDGOALS)),view)
ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
$(eval $(ARGS):;@:)
endif

view: VIEWER = $(firstword $(ARGS))
view:
	@PDFVIEWER=$$([ -z "$(VIEWER)" ] && echo $(PDFVIEWER) || echo $(VIEWER)); 						\
	if [ ! $$(command -v $$PDFVIEWER) ]; then                                   					\
		echo "Cannot view $(MAIN).pdf, Command '$$PDFVIEWER' does not exist." 1>&2;   				\
		exit 0;                                                               						\
	else																							\
		echo "$$PDFVIEWER $(MAIN).pdf";                                       						\
		nohup env -i DISPLAY=$$DISPLAY $$PDFVIEWER $(DIR)/$(MAIN).pdf </dev/null >/dev/null 2>&1 &  \
	fi;


$(BUILDDIR)/$(MAIN).fls:
	$(info $(BUILDDIR)/$(MAIN).fls)
	$(error Compilation is required in order to determine dependencies)


archive: | $(BUILDDIR)/$(MAIN).fls
archive: TARFILE = $$(echo $(ARCHIVEDIR)/$(MAIN)_$$(date +"%Y_%m_%d_%H_%M_%S") | tr -d ' ').tar
archive: $(ARCHIVEDIR)
	@echo "CREATE TAR $(TARFILE)";
	@tar --exclude=".*" -cvf $(TARFILE) --transform 's:^$(DIR:/%=%)/::' --transform 's:^$(DIR)/::' --transform 's:^:$(MAIN)/:'\
		Makefile README $(shell find $(DIR) -name '*.bib') $(shell cat $(BUILDDIR)/$(MAIN).fls | grep 'INPUT.*$(DIR)' | grep -v 'INPUT.*$(BUILDDIR)' |awk '{print $$2}' | uniq)  2>/dev/null \
		| sed 's:^:    ADD :'

update:
	@if [ -d "$(PACKAGEDIR)" ]; then 	\
		texhash $(PACKAGEDIR);          \
	fi;
	@if [ -d "$(STYLEDIR)" ]; then      \
		texhash $(STYLEDIR);			\
	fi;

force: ;

ls: force
	@if [ -f "$(BUILDDIR)/$(MAIN).fls" ]; then               \
		cat $(BUILDDIR)/$(MAIN).fls |                        \
			command grep 'INPUT.*$(DIR)' |                   \
			command grep -v 'INPUT.*$(BUILDDIR)' |           \
			command awk '{print $$2}';                       \
	else                                                     \
		echo "dependency file '$(MAIN).fls' not found" 1>&2; \
	fi;

help:
	@echo "Usage:"
	@echo "    make [options] [LATEX_INCLUDE_PATH=PATH1[:PATH2[:..]]]"
	@echo ""
	@echo "Options:"
	@echo "    pdf*          : create pdf from '$(TEXFILE)'"
	@echo "    all           : create pdf and bibtex citations"
	@echo "    bib           : create bib file"
	@echo "    bibtex        : bibtex citations"
	@echo "    clean         : remove latex build files"
	@echo "    update        : update local texhash"
	@echo "    archive       : create tarball of local files"
	@echo "    view [viewer] : open pdf with [viewer]"
	@echo "    draft         : compile as draft"
	@echo "                        For drafting, start main tex file with:"
	@echo "                        \ifdefined\isdraft"
	@echo "                            \PassOptionsToClass{draft}{<doc class>}"
	@echo "                        \fi"
	@echo "                        \documentclass[...]{<doc class>}"
	@echo ""
	@echo "    * = default"
	@echo ""
	@echo "Directory hierarchy:"
	@echo "    packages : local package directory"
	@echo "    style    : local documentclass style directory"
	@echo "    build    : latex build files"

