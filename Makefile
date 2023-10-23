# Copyright 2022 Mitchell Kember. Subject to the MIT License.

define usage
Targets:
	all        Build scripts
	help       Show this help message
	install    Symlink scripts using sim
	uninstall  Remove installed symlimks
	check      Run before committing
	fmt        Format code
	lint       Lint code
	clean      Remove build output

Variables:
	DEBUG      If nonempty, build in debug mode
endef

.PHONY: all help install uninstall check fmt lint clean

CXXFLAGS := $(shell cat compile_flags.txt) $(if $(DEBUG),-O0 -g,-O3)

script_sh := $(wildcard *.sh)
script_py := $(wildcard *.py)
script_pl := $(wildcard *.pl)
script_fish := $(wildcard *.fish)
script_all := $(script_sh) $(script_py) $(script_pl) $(script_fish)

src_cpp := $(wildcard *.cpp)
bin_cpp := $(src_cpp:%.cpp=bin/%)
bin_all := $(bin_cpp)

exe_all := $(script_all) $(bin_all)

# These are the scripts I actively use.
exe_install := \
	24bitcolor.sh \
	base16test.sh \
	clean-icloud-dups.sh \
	goodnight.sh \
	j.sh \
	journallint.py \
	kitty-bell-notify.sh \
	noextensions.sh \
	recall.sh \
	tmux-session.sh \
	tmux-set-cwd.sh \
	unquarantine.sh \
	update-zig.sh \
	z-projects.fish \
	bin/kitty-colors \
	bin/ledgerlint \
	bin/yank

.SUFFIXES:

all: $(bin_all)

help:
	$(info $(usage))
	@:

install: $(bin_all)
	sim install --no-ext $(exe_install)

uninstall:
	sim remove --target --quiet $(exe_all)

check: fmt lint all

fmt:
	black $(script_py)
	fish_indent -w $(script_fish)
	clang-format --style=file -i $(src_cpp)

lint:
	shellcheck $(script_sh)

clean:
	rm -rf bin

bin:
	mkdir $@

$(bin_cpp): bin/%: %.cpp | bin
	$(CXX) $(CXXFLAGS) -o $@ $^
