CXXFLAGS := $(shell cat compile_flags.txt) $(if $(DEBUG),-O0 -g,-O3)

script_sh := $(wildcard *.sh)
script_py := $(wildcard *.py)
script_pl := $(wildcard *.pl)
script_fish := $(wildcard *.fish)
script_all := $(script_sh) $(script_py) $(script_pl) $(script_fish)

src_cpp := $(wildcard *.cpp)
build_dir := out
build_cpp := $(addprefix $(build_dir)/,$(basename $(src_cpp)))
build_all := $(build_cpp)

exe_all := $(script_all) $(build_all)

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
	z-projects.fish \
	$(build_dir)/kitty-colors \
	$(build_dir)/ledgerlint \
	$(build_dir)/yank

define usage
Targets:
	all        Build compiled scripts
	help       Show this help message
	install    Symlink scripts using sim
	uninstall  Remove symlimks using sim
	fmt        Format code
	lint       Lint code
	clean      Remove build output
endef

.PHONY: all help install uninstall fmt lint clean

all: $(build_all)

help:
	$(info $(usage))
	@:

install: $(build_all)
	sim install --no-ext $(exe_install)

uninstall:
	sim remove --target --quiet $(exe_all)

$(build_dir):
	mkdir -p $@

$(build_cpp): $(build_dir)/%: %.cpp | $(build_dir)
	$(CXX) $(CXXFLAGS) -o $@ $^

fmt:
	black .
	clang-format --style=file -i $(src_cpp)

lint:
	shellcheck $(wildcard *.sh)

clean:
	rm -rf $(build_dir)
