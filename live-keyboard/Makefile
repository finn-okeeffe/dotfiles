CC ?= gcc
CFLAGS ?= -O2 -Wall -Wextra -Wpedantic
LDFLAGS ?=
LDLIBS ?= -Wl,-l:libasound.so.2

.PHONY: all clean

all: keylab-essential-ardour-cc-floor

keylab-essential-ardour-cc-floor: keylab-essential-ardour-cc-floor.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $< $(LDLIBS)

clean:
	$(RM) keylab-essential-ardour-cc-floor
