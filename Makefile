export

SHELL = /bin/bash
PYTHON = python
PIP = pip
LOG_LEVEL = INFO
PYTHONIOENCODING=utf8
TESTDIR = tests

BUILD_ORDER = ocrd_utils ocrd_models ocrd_modelfactory ocrd_validators ocrd

FIND_VERSION = grep version= ocrd_utils/setup.py|grep -Po "([0-9ab]+\.?)+"

# BEGIN-EVAL makefile-parser --make-help Makefile

help:
	@echo ""
	@echo "  Targets"
	@echo ""
	@echo "    deps-ubuntu    Dependencies for deployment in an ubuntu/debian linux"
	@echo "    deps-test      Install test python deps via pip"
	@echo "    install        (Re)install the tool"
	@echo "    generate-page  Regenerate python code from PAGE XSD"
	@echo "    repo/assets    Clone OCR-D/assets to ./repo/assets"
	@echo "    repo/spec      Clone OCR-D/spec to ./repo/spec"
	@echo "    spec           Copy JSON Schema, OpenAPI from OCR-D/spec"
	@echo "    assets         Setup test assets"
	@echo "    assets-server  Start asset server at http://localhost:5001"
	@echo "    assets-clean   Remove symlinks in $(TESTDIR)/assets"
	@echo "    test           Run all unit tests"
	@echo "    docs           Build documentation"
	@echo "    docs-clean     Clean docs"
	@echo "    docker         Build docker image"
	@echo "    bashlib        Build bash library"
	@echo "    pypi           Build wheels in py2 and py3 venv and twine upload them"
	@echo ""
	@echo "  Variables"
	@echo ""
	@echo "    DOCKER_TAG  Docker tag."

# END-EVAL

# Docker tag.
DOCKER_TAG = 'ocrd/pyocrd'

# pip install command. Default: $(PIP_INSTALL)
PIP_INSTALL = pip install

# Dependencies for deployment in an ubuntu/debian linux
deps-ubuntu:
	sudo apt install -y python3 python3-pip

# Install test python deps via pip
deps-test:
	$(PIP) install -r requirements_test.txt

# (Re)install the tool
install: spec
	for mod in $(BUILD_ORDER);do (cd $$mod ; $(PIP_INSTALL) .);done

# Uninstall the tool
uninstall:
	for mod in $(BUILD_ORDER);do pip uninstall -y $$mod;done

# Regenerate python code from PAGE XSD
generate-page: repo/assets
	generateDS \
		-f \
		--no-namespace-defs \
		--root-element='PcGts' \
		-o ocrd_models/ocrd_models/ocrd_page_generateds.py \
		repo/assets/data/schema/2018.xsd

#
# Repos
#

# Clone OCR-D/assets to ./repo/assets
repo/assets:
	mkdir -p $(dir $@)
	git clone https://github.com/OCR-D/assets "$@"

# Clone OCR-D/spec to ./repo/spec
repo/spec:
	mkdir -p $(dir $@)
	git clone https://github.com/OCR-D/spec "$@"

#
# Spec
#

.PHONY: spec
# Copy JSON Schema, OpenAPI from OCR-D/spec
spec: repo/spec
	cp repo/spec/ocrd_tool.schema.yml ocrd_validators/ocrd_validators/ocrd_tool.schema.yml
	cp repo/spec/bagit-profile.yml ocrd_validators/ocrd_validators/bagit-profile.yml

#
# Assets
#

# Setup test assets
assets: repo/assets
	mkdir -p $(TESTDIR)/assets
	cp -r -t $(TESTDIR)/assets repo/assets/data/*

# Start asset server at http://localhost:5001
assets-server:
	cd assets && make start

# Remove symlinks in $(TESTDIR)/assets
assets-clean:
	rm -rf $(TESTDIR)/assets

#
# Tests
#

.PHONY: test
# Run all unit tests
test: spec assets
	$(PYTHON) -m pytest --duration=10 --continue-on-collection-errors $(TESTDIR)

test-profile:
	$(PYTHON) -m cProfile -o profile $$(which pytest)
	$(PYTHON) analyze_profile.py

coverage:
	coverage erase
	make test PYTHON="coverage run"
	coverage report

#
# Documentation
#

.PHONY: docs
# Build documentation
docs: gh-pages
	sphinx-apidoc -f -o docs/api ocrd
	cd docs ; $(MAKE) html
	cp -r docs/build/html/* gh-pages
	cd gh-pages; git add . && git commit -m 'Updated docs $$(date)' && git push

# Clean docs
docs-clean:
	cd docs ; rm -rf _build api

gh-pages:
	git clone --branch gh-pages https://github.com/OCR-D/pyocrd gh-pages

#
# Clean up
#

pyclean:
	rm -f **/*.pyc
	find . -name '__pycache__' -exec rm -rf '{}' \;
	rm -rf .pytest_cache

#
# Docker
#

# Build docker image
docker:
	docker build -t $(DOCKER_TAG) .

#
# bash library
#
.PHONY: bashlib

# Build bash library
bashlib:
	cd bashlib; make lib

# Build wheels and source dist and twine upload them
pypi: uninstall install
	for mod in $(BUILD_ORDER);do (cd $$mod; $(PYTHON) setup.py sdist bdist_wheel);done
	version=`$(FIND_VERSION)`; echo twine upload ocrd*/dist/ocrd*$$version*{tar.gz,whl}
