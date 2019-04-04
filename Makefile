TOP=../../..

BINS=\
 fglprogress.42m\
 fglprogress.42f\
 fglprogress_demo.42m\
 fglprogress_demo.42f

all: $(BINS) doc

run:: $(BINS)
	fglrun fglprogress_demo

doc: docs/fglprogress.html

docs/fglprogress.html: fglprogress.4gl
	fglcomp --build-doc fglprogress.4gl
	mv fglprogress.html docs

fglprogress.42m: fglprogress.4gl
	fglcomp -M fglprogress.4gl

fglprogress.42f: fglprogress.per
	fglform -M fglprogress.per

fglprogress_demo.42m: fglprogress_demo.4gl fglprogress.4gl
	fglcomp -M fglprogress_demo.4gl

fglprogress_demo.42f: fglprogress_demo.per
	fglform -M fglprogress_demo.per

fglprogress_demo.gar: $(BINS)
	fglgar gar --application fglprogress_demo.42m -o fglprogress_demo.gar

fglprogress_demo.war: fglprogress_demo.gar
	fglgar war --input-gar fglprogress_demo.gar --output fglprogress_demo.war

runjgas: fglprogress_demo.war
	fglgar run --war fglprogress_demo.war

clean::
	rm -f *.42m *.42f *.gar *.war fglprogress.html fglprogress.xa
