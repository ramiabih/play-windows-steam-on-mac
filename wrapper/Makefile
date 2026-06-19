#
# Cross-compile steamwebhelper-wrapper for Windows x86_64.
# Requires: brew install mingw-w64

TARGET  ?= steamwebhelper.exe
CC      ?= x86_64-w64-mingw32-gcc
CFLAGS  ?= -O2 -Wall -Wextra -municode -DUNICODE -D_UNICODE
LDFLAGS ?= -static -lshell32 -mwindows
SRC      = src/steamwebhelper-wrapper.c

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f $(TARGET)
