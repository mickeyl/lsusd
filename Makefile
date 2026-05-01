PYTHON ?= python3
PIP ?= $(PYTHON) -m pip
PIP_INSTALL_FLAGS ?= $(shell $(PYTHON) -c 'import sys; print("" if sys.prefix != sys.base_prefix else "--user --break-system-packages")')

.PHONY: help install uninstall check run watch clean

help:
	@echo "Targets:"
	@echo "  make install    Install this project editable into the active Python environment"
	@echo "  make uninstall  Uninstall the package from the active Python environment"
	@echo "  make check      Compile sources and show CLI help"
	@echo "  make run        Run lsusd from the source tree"
	@echo "  make watch      Run lsusd --watch from the source tree"
	@echo "  make clean      Remove Python cache files"

install:
	$(PIP) install $(PIP_INSTALL_FLAGS) -e .

uninstall:
	$(PIP) uninstall -y lsusd

check:
	$(PYTHON) -m compileall -q src
	PYTHONPATH=src $(PYTHON) -m lsusd --help

run:
	@PYTHONPATH=src $(PYTHON) -m lsusd

watch:
	@PYTHONPATH=src $(PYTHON) -m lsusd --watch || test $$? -eq 130

clean:
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
	find . -type f -name '*.py[co]' -delete
