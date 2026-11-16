# Lab test for C:make on GFOS: recipes through the Shell, rebuilds by date,
# pattern rules, AmigaDOS paths and wildcards.
#   make -f recipes.mk clean     then
#   make -f recipes.mk check     (prints "recipes: passed")
# Works in T:mktest. MIT, Copyright (c) 2026 AmiCradle Team.
D = T:mktest/
.PHONY: all clean check

all: $(D)out.txt $(D)a.o $(D)b.o

$(D)in.txt:
	Echo >$@ "input"

$(D)out.txt: $(D)in.txt
	Copy $< TO $@ QUIET

$(D)%.c:
	Echo >$@ "source $*"

$(D)%.o: $(D)%.c
	Copy $< TO $@ QUIET

clean:
	-Delete $(D) ALL QUIET FORCE
	MakeDir $(D)

check: all
	@$(if $(filter 4,$(words $(wildcard $(D)*.txt $(D)*.o))),,$(error FAIL wildcard: $(wildcard $(D)*)))
	@$(if $(filter input,$(shell Type $(D)out.txt)),,$(error FAIL out.txt))
	@$(if $(filter source a,$(shell Type $(D)a.o)),,$(error FAIL a.o))
	@echo "recipes: passed"
