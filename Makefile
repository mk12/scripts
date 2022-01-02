CXXFLAGS := -std=c++17 -W -Wall $(if $(DEBUG),-O0 -g,-O3)

script_sh := $(wildcard *.sh)
script_py := $(wildcard *.py)
script_pl := $(wildcard *.pl)
script_all := $(script_sh) $(script_py) $(script_pl)

src_cpp := $(wildcard *.cpp)
build_dir := out
build_cpp := $(addprefix $(build_dir)/,$(basename $(src_cpp)))
build_all := $(build_cpp)

exe_all := $(script_all) $(build_all)

.PHONY: all help install uninstall fmt lint clean

all: $(build_all)

help:
	@echo "Targets:"
	@echo "all       build compiled scripts"
	@echo "help      show this help message"
	@echo "install   symlink scripts using sim"
	@echo "uninstall remove symlimks using sim"
	@echo "fmt       format code"
	@echo "lint      lint code"
	@echo "clean     remove build output"

install:
	sim install --no-ext $(exe_all)

uninstall:
	sim remove --target --quiet $(exe_all)

$(build_dir):
	mkdir $@

$(build_cpp): $(build_dir)/%: %.cpp | $(build_dir)
	$(CXX) $(CXXFLAGS) -o $@ $^

fmt:
	black .
	clang-format --style=file -i $(src_cpp)

lint:
	shellcheck $(script_sh)

clean:
	rm -rf $(build_dir)
