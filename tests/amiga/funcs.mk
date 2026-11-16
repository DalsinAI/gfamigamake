# Lab test for C:make on GFOS: the language without the Shell.
#   make -f funcs.mk        (prints "funcs: all N checks passed")
# MIT, Copyright (c) 2026 AmiCradle Team.
n :=
check = $(if $(filter-out $(strip $2),$(strip $1))$(filter-out $(strip $1),$(strip $2)),$(error FAIL $3: got '$(strip $1)' want '$(strip $2)'),$(eval n += x))

A = one two three
B := $(A) four
C ?= set
C ?= not
$(call check,$(B),one two three four,simple and recursive)
$(call check,$(C),set,conditional assignment)
$(call check,$(words $(B)),4,words)
$(call check,$(word 2,$(B)),two,word)
$(call check,$(patsubst %.c,%.o,a.c b.c c.h),a.o b.o c.h,patsubst)
$(call check,$(A:e=E),onE two threE,substitution reference)
$(call check,$(subst o,0,foo),f00,subst)
$(call check,$(sort c a b a),a b c,sort)
$(call check,$(filter %.c,a.c b.h c.c),a.c c.c,filter)
$(call check,$(foreach v,1 2 3,<$(v)>),<1> <2> <3>,foreach)
$(call check,$(if ,yes,no),no,if)
$(call check,$(or ,,x),x,or)
$(call check,$(and a,b),b,and)
$(call check,$(dir Work:src/main.c),Work:src/,dir with a device)
$(call check,$(notdir Work:src/main.c),main.c,notdir with a device)
$(call check,$(suffix a.c b.h),.c .h,suffix)
$(call check,$(basename src/a.c),src/a,basename)
$(call check,$(addprefix T:,a b),T:a T:b,addprefix)
$(call check,$(firstword x y),x,firstword)
$(call check,$(lastword x y),y,lastword)
$(call check,$(intcmp 2,3,lt,eq,gt),lt,intcmp)
$(call check,$(let a b,1 2 3,$(b)),2 3,let)
define two
line1
line2
endef
$(call check,$(words $(two)),2,define)
ifeq ($(A),one two three)
I = yes
else
I = no
endif
$(call check,$(I),yes,ifeq)
ifdef UNSET
J = bad
endif
$(call check,$(J),,ifdef)
$(call check,$(origin A),file,origin)
$(call check,$(flavor B),simple,flavor)
$(call check,$(value A),one two three,value)
$(call check,$(MAKE_VERSION),4.4.1,MAKE_VERSION)

$(info funcs: all $(words $(n)) checks passed)
.PHONY: all
all: ;
