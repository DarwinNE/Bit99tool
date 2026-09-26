CC = clang

CFLAGS = -Wall -Wextra -O2

OBJCFLAGS = $(CFLAGS) -fobjc-arc

LDFLAGS = -framework Cocoa -framework CoreMIDI 

APP = Bit99Tool.app
BINARY = $(APP)/Contents/MacOS/Bit99Tool

RESOURCE_DIR = $(APP)/Contents/Resources
RESOURCES = res/bit_logo.png \
    res/dseg7-classic-latin-300-normal.ttf \
    res/LICENSE_dseg7


C_SOURCES = \
	src/bit99_handler.c

OBJC_SOURCES = \
	src/main.m \
	src/gui.m \
	src/sysex_window.m

C_OBJECTS = \
	src/bit99_handler.o \
	src/bit99_midi.o \
	src/macos_midi.o \
	src/bit99_program.o

OBJC_OBJECTS = \
	src/main.o \
	src/gui.o \
	src/sysex_window.o

OBJECTS = $(C_OBJECTS) $(OBJC_OBJECTS)


all: $(APP)


$(APP): $(BINARY)
	@echo "Built $(APP)"

	
$(BINARY): $(OBJECTS) Info.plist $(RESOURCES)
	@mkdir -p $(APP)/Contents/MacOS
	@mkdir -p $(RESOURCE_DIR)
	@cp Info.plist $(APP)/Contents/Info.plist
	@cp res/bit_logo.png $(RESOURCE_DIR)/
	@cp res/dseg7-classic-latin-300-normal.ttf $(RESOURCE_DIR)/
	@cp res/LICENSE_dseg7 $(RESOURCE_DIR)/

	$(CC) $(OBJECTS) -o $(BINARY) $(LDFLAGS)

	$(CC) $(OBJECTS) -o $(BINARY) $(LDFLAGS)


src/bit99_handler.o: src/bit99_handler.c src/bit99_handler.h
	$(CC) $(CFLAGS) -c src/bit99_handler.c -o src/bit99_handler.o

src/bit99_midi.o: src/bit99_midi.c src/bit99_midi.h
	$(CC) $(CFLAGS) -c src/bit99_midi.c -o src/bit99_midi.o

#src/bit99.o: src/bit99.c src/bit99.h
#	$(CC) $(CFLAGS) -c src/bit99.c -o src/bit99.o

src/macos_midi.o: src/macos_midi.c src/macos_midi.h
	$(CC) $(CFLAGS) -c src/macos_midi.c -o src/macos_midi.o

src/main.o: src/main.m src/gui.h
	$(CC) $(OBJCFLAGS) -c src/main.m -o src/main.o

src/sysex_window.o: src/sysex_window.m src/gui.h src/sysex_window.h
	$(CC) $(OBJCFLAGS) -c src/sysex_window.m -o src/sysex_window.o

src/gui.o: src/gui.m src/gui.h src/bit99_handler.h
	$(CC) $(OBJCFLAGS) -c src/gui.m -o src/gui.o




run: $(APP)
	open $(APP)


clean:
	rm -rf $(OBJECTS) $(APP)


.PHONY: all run clean

