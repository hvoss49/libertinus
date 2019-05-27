NAME=Libertinus
VERSION=6.9

DIST=$(NAME)-$(VERSION)

SOURCEDIR=sources
BUILDDIR=build
GSUB=$(SOURCEDIR)/features/gsub.fea
DOC=documentation
TOOLS=tools

PY?=python
BUILD=$(TOOLS)/build.py
NORMALIZE=$(TOOLS)/sfdnormalize.py
CHECKERRS=$(TOOLS)/check-errors.py
LO?=lowriter

NULL=

FONTS=Sans-Regular \
       Sans-Bold \
       Sans-Italic \
       Serif-Regular \
       Serif-Semibold \
       Serif-Bold \
       Serif-Italic \
       Serif-SemiboldItalic \
       Serif-BoldItalic \
       SerifDisplay-Regular \
       Math-Regular \
       SerifInitials-Regular \
       Mono-Regular \
       Keyboard-Regular \
       $(NULL)

SFD=$(FONTS:%=$(SOURCEDIR)/$(NAME)%.sfd)
NRM=$(FONTS:%=$(BUILDDIR)/$(NAME)%.nrm)
CHK=$(FONTS:%=$(BUILDDIR)/$(NAME)%.chk)
DUP=$(FONTS:%=$(BUILDDIR)/$(NAME)%.dup)
LNT=$(FONTS:%=$(BUILDDIR)/$(NAME)%.lnt)
OTF=$(FONTS:%=$(NAME)%.otf)
PDF=$(FONTS:%=$(DOC)/$(NAME)%-Table.pdf)
PNG=$(DOC)/preview.png
OPDF=$(DOC)/Opentype-Features.pdf $(DOC)/Sample.pdf

export SOURCE_DATE_EPOCH ?= 0

.SECONDARY:

all: otf

otf: $(OTF)
doc: $(PDF) $(OPDF)
normalize: $(NRM)
check: $(LNT) $(CHK) $(DUP)


nofea=$(strip $(foreach f,Initials Keyboard Mono,$(findstring $f,$1)))

$(BUILDDIR)/%.ff.otf: $(SOURCEDIR)/%.sfd $(GSUB) $(BUILD)
	@echo "   BUILD	$(*F)"
	@mkdir -p $(BUILDDIR)
	@$(PY) $(BUILD)                                                        \
		-i $<                                                          \
		-o $@                                                          \
		-v $(VERSION)                                                  \
		$(if $(call nofea,$@),,-f $(GSUB))                             \
		;

$(BUILDDIR)/%.hint.otf: $(BUILDDIR)/%.ff.otf
	@echo "   HINT		$(*F)"
	@rm -rf $@.log
	@psautohint $< -o $@ --log $@.log

$(BUILDDIR)/%.subset.otf: $(BUILDDIR)/%.hint.otf
	@echo "   PRUNE	$(*F)"
	@fonttools subset                                                      \
		--unicodes='*'                                                 \
		--layout-features='*'                                          \
		--name-IDs='*'                                                 \
		--notdef-outline                                               \
		--recalc-average-width                                         \
		--recalc-bounds                                                \
		--drop-tables=FFTM                                             \
		--output-file=$@                                               \
		$<                                                             \
		;

%.otf: $(BUILDDIR)/%.subset.otf
	@cp $< $@

$(BUILDDIR)/%.nrm: $(SOURCEDIR)/%.sfd $(NORMALIZE)
	@echo "   NORMALIZE	$(*F)"
	@mkdir -p $(BUILDDIR)
	@$(PY) $(NORMALIZE) $< $@
	@if [ "`diff -u $< $@`" ]; then cp $@ $<; touch $@; fi

$(BUILDDIR)/%.chk: $(SOURCEDIR)/%.sfd $(NORMALIZE)
	@echo "   NORMALIZE	$(*F)"
	@mkdir -p $(BUILDDIR)
	@$(PY) $(NORMALIZE) $< $@
	@diff -u $< $@ || (rm -rf $@ && false)

$(BUILDDIR)/%.dup: $(SOURCEDIR)/%.sfd $(FINDDUPS)
	@echo "   CHECK	$(*F)"
	@mkdir -p $(BUILDDIR)
	@$(PY) $(CHECKERRS) $< $@ || (rm -rf $@ && false)


# Currently ignored errors:
#  2: Self-intersecting glyph
#  5: Missing points at extrema
#  7: More points in a glyph than PostScript allows
# 23: Overlapping hints in a glyph
$(BUILDDIR)/LibertinusKeyboard-Regular.lnt: LibertinusKeyboard-Regular.otf
	@echo "   LINT		LibertinusKeyboard-Regular"
	@mkdir -p $(BUILDDIR)
	@fontlint -i2,5,7,23 $< 2>/dev/null 1>$@ || (cat $@ && rm -rf $@ && false)

$(BUILDDIR)/LibertinusSerifInitials-Regular.lnt: LibertinusSerifInitials-Regular.otf
	@echo "   LINT		LibertinusSerifInitials-Regular"
	@mkdir -p $(BUILDDIR)
	@fontlint -i2,5,7,23,34 $< 2>/dev/null 1>$@ || (cat $@ && rm -rf $@ && false)

# Currently ignored errors:
#  2: Self-intersecting glyph
#  5: Missing points at extrema
# 34: Bad 'CFF ' table
# 98: Self-intersecting glyph when FontForge is able to correct this
$(BUILDDIR)/%.lnt: %.otf
	@echo "   LINT		$(*F)"
	@mkdir -p $(BUILDDIR)
	@fontlint -i2,5,34,98 $< 2>/dev/null 1>$@ || (cat $@ && rm -rf $@ && false)

$(DOC)/%-Table.pdf: %.otf
	@echo "   PDF	$@"
	@mkdir -p $(DOC)
	@fntsample --font-file $< --output-file $@                             \
		   --write-outline --use-pango                                 \
		   --style="header-font: Noto Sans Bold 12"                    \
		   --style="font-name-font: Noto Serif Bold 12"                \
		   --style="table-numbers-font: Noto Sans 10"                  \
		   --style="cell-numbers-font:Noto Sans Mono 8"

$(DOC)/%.pdf: $(DOC)/%.fodt
	@echo "   PDF	$@"
	@mkdir -p $(DOC)
	@VCL_DEBUG_DISABLE_PDFCOMPRESSION=1 LC_ALL=en_US.utf-8 \
	 $(LO) --convert-to pdf --outdir $(DOC) $< 1> /dev/null

$(DOC)/preview.png: $(DOC)/preview.tex $(OTF)
	@echo "   PNG	$@"
	@xelatex --interaction=batchmode -output-directory=$(dir $@) $<
	@pdftocairo -png -singlefile -r 300 $(basename $@).pdf $(basename $@)

dist: check $(OTF) $(PDF) $(OPDF) $(PNG)
	@echo "   DST	$(DIST).zip"
	@rm -rf $(DIST) $(DIST).zip
	@mkdir -p $(DIST)/$(DOC)
	@cp $(OTF) $(DIST)
	@cp $(PDF) $(OPDF) $(PNG) $(DIST)/$(DOC)
	@cp $(DOC)/Math-Sample.pdf $(DIST)/$(DOC)
	@cp OFL.txt FONTLOG.txt AUTHORS.txt $(DIST)
	@cp README.md $(DIST)/README.txt
	@zip -rq $(DIST).zip $(DIST)

clean:
	@rm -rf $(DIST) $(DIST).zip $(CHK) $(MIS) $(DUP) $(FEA) $(NRM) $(LNT) \
		$(PDF) $(OTF) $(OPDF)
