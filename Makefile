PROJECT=main
PRESENT=present
TEX=lualatex
BIBTEX=bibtex
TEXOPTS=-interaction=nonstopmode -halt-on-error
BUILDTEX=$(TEX) $(TEXOPTS) $(PROJECT).tex

# Most figures are standalone LaTeX documents that the chapters pull in with
# \includegraphics, so each has to be compiled to PDF before the main document
# can find it.  Each figure resolves its data paths relative to its own
# directory, so it must be compiled from there.
FIGSRC := $(shell grep -l '^\\documentclass' */fig-*.tex)
FIGPDF := $(FIGSRC:.tex=.pdf)

all: figures
	$(BUILDTEX)
	-$(BIBTEX) $(PROJECT)
	$(BUILDTEX)
	$(BUILDTEX)

figures: $(FIGPDF)

# Reading copy: same text, single spaced.  The double-spaced main.pdf is what
# the Graduate School required; this is the one that is pleasant to read.
READING=$(TEX) $(TEXOPTS) -jobname=reading "\def\readingcopy{}\input{$(PROJECT)}"
reading: figures
	$(READING)
	-$(BIBTEX) reading
	$(READING)
	$(READING)

dfo/fig-%.pdf: dfo/fig-%.tex
	cd dfo && $(TEX) $(TEXOPTS) fig-$*.tex
jcc/fig-%.pdf: jcc/fig-%.tex
	cd jcc && $(TEX) $(TEXOPTS) fig-$*.tex
msip/fig-%.pdf: msip/fig-%.tex
	cd msip && $(TEX) $(TEXOPTS) fig-$*.tex

once:
	$(BUILDTEX)
one:
	$(TEX) -jobname=one "\includeonly{msip/msip}\input{$(PROJECT)}"
two:
	$(TEX) -jobname=two "\includeonly{dfo/dfo}\input{$(PROJECT)}"
ftwo:
	$(TEX) -jobname=two "\includeonly{front,dfo/dfo}\input{$(PROJECT)}"
three:
	$(TEX) -jobname=three "\includeonly{jcc/jcc}\input{$(PROJECT)}"
four:
	$(TEX) -jobname=four "\includeonly{oj/oj}\input{$(PROJECT)}"
tf:
	$(TEX) -jobname=tf "\includeonly{jcc/jcc,oj/oj}\input{$(PROJECT)}"
intro:
	$(TEX) -jobname=intro "\includeonly{intro/intro}\input{$(PROJECT)}"
title:
	$(TEX) -jobname=title "\includeonly{front}\input{$(PROJECT)}"
present:
	$(TEX) $(PRESENT).tex

clean:
	rm -f *.aux *.log *.out	*.idx *.lot *.lof *.gz *.toc *~ *.blg *.auxlock *.bbl *.ent
	rm -f */*.aux */*.log */*.out	*/*.idx */*.lot */*.lof */*.gz */*.toc */*~ */*.blg */*.auxlock */*.bbl */*.ent

# also drop the compiled figure PDFs
distclean: clean
	rm -f $(FIGPDF) $(PROJECT).pdf

.PHONY: all figures once one two ftwo three four tf intro title present clean distclean
