CXX := clang++
OFLAGS := -O3
CXXFLAGS := -std=c++17 -Weverything -Wno-c++98-compat -Wno-padded

PROGRAMS := inline_svg kitty-colors

.phony: all clean

all: $(PROGRAMS)

clean:
	rm -f $(PROGRAMS)

%: %.cpp
	$(CXX) $(CXXFLAGS) $(OFLAGS) -o $@ $<
