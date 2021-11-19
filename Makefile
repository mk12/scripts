SHELL := /bin/bash

PREFIX ?= $(HOME)/.local
CXXFLAGS := -std=c++17 -W -Wall $(if $(DEBUG),-O0 -g,-O3)

src := $(shell pwd)
src_sh := $(wildcard *.sh)
src_py := $(wildcard *.py)
src_pl := $(wildcard *.pl)
src_cpp := $(wildcard *.cpp)

build := bin
build_cpp := $(addprefix $(build)/,$(basename $(src_cpp)))
build_all := $(build_cpp)

dst := $(PREFIX)/bin
dst_sh := $(addprefix $(dst)/,$(basename $(src_sh)))
dst_py := $(addprefix $(dst)/,$(basename $(src_py)))
dst_pl := $(addprefix $(dst)/,$(basename $(src_pl)))
dst_cpp := $(addprefix $(dst)/,$(basename $(src_cpp)))
dst_all := $(dst_sh) $(dst_py) $(dst_pl) $(dst_cpp)

# Disable implicit rules.
.SUFFIXES:

.PHONY: all help clean lint

all: $(build_all)

help:
	@echo "Targets:"
	@echo "all       build compiled scripts"
	@echo "help      show this help message"
	@echo "install   symlink scripts in $(PREFIX)"
	@echo "uninstall remove installed symlimks"
	@echo "fmt       format code"
	@echo "lint      lint code"
	@echo "clean     remove build output"

install: $(dst_all)

uninstall:
	@for f in $(dst_all); do \
		if [[ -L "$$f" ]] && [[ $$(readlink "$$f") = '$(src)/'* ]]; then \
			echo "Removing $$f"; \
			unlink "$$f"; \
		elif [[ -f "$$f" ]]; then \
			echo "Not removing $$f (did not come from this repository)"; \
		fi; \
	done

$(dst)/%:
	@test -n "$<" || { echo "$(notdir $@): unknown script"; false; }
	@mkdir -p $(dst)
	ln -sf $(src)/$< $@

$(dst_sh): $(dst)/%: %.sh
$(dst_py): $(dst)/%: %.py
$(dst_pl): $(dst)/%: %.pl
$(dst_cpp): $(dst)/%: $(build)/%

$(build_cpp): $(build)/%: %.cpp
	@mkdir -p $(build)
	$(CXX) $(CXXFLAGS) -o $@ $^

fmt:
	black .
	clang-format --style=file -i $(src_cpp)

lint:
	shellcheck -e SC1090 $(wildcard *.sh)

clean:
	rm -rf $(build)
