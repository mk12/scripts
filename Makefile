CXX := clang++
CXXFLAGS := -std=c++17 -Weverything -Wno-c++98-compat \
	-Wno-c++98-compat-pedantic -Wno-c99-extensions -Wno-padded

DEBUG ?= 0
ifeq ($(DEBUG),1)
OFLAGS := -O0 -g
else
OFLAGS := -O3
endif

PROGRAMS := inline_svg kitty-colors ledgerlint yank

.PHONY: all clean lint

all: $(PROGRAMS)

clean:
	rm -f $(PROGRAMS)
	rm -rf *.dSYM

%: %.cpp
	$(CXX) $(CXXFLAGS) $(OFLAGS) -o $@ $<

lint: $(wildcard *.sh)
	shellcheck -e SC1090 $^
