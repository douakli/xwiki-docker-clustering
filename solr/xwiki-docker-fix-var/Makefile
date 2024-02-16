#Compiler options
CC=gcc
CFLAGS=-Wall -Winline -lm -O2 -flto -march=native -ftree-vectorize -pipe

#Project-specific configuration
srcdir=src
bindir=bin
#docdir=doc

PROG=xwiki-docker-fix-var

#Auto find source files
SRC=$(filter-out src/main.c,$(wildcard src/*.c))
OBJ=$(subst $(srcdir), $(bindir), $(SRC:.c=.o))

#Builds everything. (i.e the main program)
all: $(bindir)/${PROG}

#Links the main executable
$(bindir)/$(PROG): $(bindir)/main.o $(OBJ)
	@mkdir -p $(bindir)
	${CC} ${CFLAGS} -o $@ $< ${OBJ}

$(bindir)/main.o: $(srcdir)/main.c
	@mkdir -p $(bindir)
	${CC} -c ${CFLAGS} -o $@ $<

#Compiles the source code into object files
$(bindir)/%.o: $(srcdir)/%.c $(srcdir)/%.h
	@mkdir -p $(bindir)
	${CC} -c ${CFLAGS} -o $@ $<

#Cleans files created by running make
clean:
	rm -rf $(bindir)
	rm -rf *.error *.out

save:
	@[ -z "$(shell git stash list)" ] || (echo "A save already exists." && false)
	git stash push
	git stash apply || (echo -e "\nNothing to save." && false)

restore:
	[ -n "$(shell git stash list)" ]
	git stash push
	git stash drop
	git stash pop

#Forces targets building despite their existence.
.PHONY: all clean doc save restore
