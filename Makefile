# This file is part of schema-salad,
# https://github.com/common-workflow-language/schema-salad/, and is
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Contact: common-workflow-language@googlegroups.com

# make format to fix most python formatting errors
# make pylint to check Python code for enhanced compliance including naming
#  and documentation
# make coverage-report to check coverage of the python scripts by the tests

MODULE=schema_salad
PACKAGE=schema-salad

# `SHELL=bash` doesn't work for some, so don't use BASH-isms like
# `[[` conditional expressions.
PYSOURCES=$(wildcard ${MODULE}/**.py ${MODULE}/avro/*.py ${MODULE}/tests/*.py) setup.py
DEVPKGS=diff_cover black pylint coverage pep257 pydocstyle flake8 mypy\
	isort wheel autoflake flake8-bugbear pyupgrade pytest-xdist \
COVBASE=coverage run --branch --append --source=${MODULE} \
	--omit=schema_salad/tests/*

# Updating the Major & Minor version below?
# Don't forget to update setup.py as well
VERSION=7.0.$(shell date +%Y%m%d%H%M%S --utc --date=`git log --first-parent \
	--max-count=1 --format=format:%cI`)

## all         : default task
all:
	pip install -e .

## help        : print this help message and exit
help: Makefile
	@sed -n 's/^##//p' $<

## install-dep : install most of the development dependencies via pip
install-dep: install-dependencies

install-dependencies:
	pip install --upgrade $(DEVPKGS)
	pip install -r requirements.txt

## install     : install the ${MODULE} module and schema-salad-tool
install: FORCE
	pip install .

## dist        : create a module package for distribution
dist: dist/${MODULE}-$(VERSION).tar.gz

dist/${MODULE}-$(VERSION).tar.gz: $(SOURCES)
	./setup.py sdist bdist_wheel

## clean       : clean up all temporary / machine-generated files
clean: FORCE
	rm -f ${MODILE}/*.pyc tests/*.pyc
	./setup.py clean --all || true
	rm -Rf .coverage
	rm -f diff-cover.html

# Linting and code style related targets
## sorting imports using isort: https://github.com/timothycrosley/isort
sort_imports: $(filter-out schema_salad/metaschema.py,$(PYSOURCES))
	isort $^

remove_unused_imports: $(filter-out schema_salad/metaschema.py,$(PYSOURCES))
	autoflake --in-place --remove-all-unused-imports $^

pep257: pydocstyle
## pydocstyle      : check Python code style
pydocstyle: $(PYSOURCES)
	pydocstyle --add-ignore=D100,D101,D102,D103 $^ || true

pydocstyle_report.txt: $(PYSOURCES)
	pydocstyle setup.py $^ > $@ 2>&1 || true

diff_pydocstyle_report: pydocstyle_report.txt
	diff-quality --compare-branch=main --violations=pycodestyle --fail-under=100 $^

## format      : check/fix all code indentation and formatting (runs black)
format:
	black --exclude metaschema.py schema_salad setup.py

## pylint      : run static code analysis on Python code
pylint: $(PYSOURCES)
	pylint --msg-template="{path}:{line}: [{msg_id}({symbol}), {obj}] {msg}" \
                $^ -j0|| true

pylint_report.txt: ${PYSOURCES}
	pylint --msg-template="{path}:{line}: [{msg_id}({symbol}), {obj}] {msg}" \
		$^ -j0> $@ || true

diff_pylint_report: pylint_report.txt
	diff-quality --violations=pylint pylint_report.txt

.coverage: $(PYSOURCES) all
	rm -f .coverage
	$(COVBASE) setup.py test
	$(COVBASE) -m schema_salad.main \
		--print-jsonld-context schema_salad/metaschema/metaschema.yml \
		> /dev/null
	$(COVBASE) -m schema_salad.main \
		--print-rdfs schema_salad/metaschema/metaschema.yml \
		> /dev/null
	$(COVBASE) -m schema_salad.main \
		--print-avro schema_salad/metaschema/metaschema.yml \
		> /dev/null
	$(COVBASE) -m schema_salad.main \
		--print-rdf schema_salad/metaschema/metaschema.yml \
		> /dev/null
	$(COVBASE) -m schema_salad.main \
		--print-pre schema_salad/metaschema/metaschema.yml \
		> /dev/null
	$(COVBASE) -m schema_salad.main \
		--print-index schema_salad/metaschema/metaschema.yml \
		> /dev/null
	$(COVBASE) -m schema_salad.main \
		--print-metadata schema_salad/metaschema/metaschema.yml \
		> /dev/null
	$(COVBASE) -m schema_salad.makedoc \
		schema_salad/metaschema/metaschema.yml \
		> /dev/null

coverage.xml: .coverage
	coverage xml

coverage.html: htmlcov/index.html

htmlcov/index.html: .coverage
	coverage html
	@echo Test coverage of the Python code is now in htmlcov/index.html

coverage-report: .coverage
	coverage report

diff-cover: coverage.xml
	diff-cover $^

diff-cover.html: coverage.xml
	diff-cover $^ --html-report $@

## test        : run the ${MODULE} test suite
test: FORCE
	python setup.py test --addopts "-n auto"

sloccount.sc: ${PYSOURCES} Makefile
	sloccount --duplicates --wide --details $^ > $@

## sloccount   : count lines of code
sloccount: ${PYSOURCES} Makefile
	sloccount $^

list-author-emails:
	@echo 'name, E-Mail Address'
	@git log --format='%aN,%aE' | sort -u | grep -v 'root'

mypy3: mypy
mypy: ${PYSOURCES}
	if ! test -f $(shell python3 -c 'import ruamel.yaml; import os.path; print(os.path.dirname(ruamel.yaml.__file__))')/py.typed ; \
	then \
		rm -Rf typeshed/2and3/ruamel/yaml ; \
		ln -s $(shell python3 -c 'import ruamel.yaml; import os.path; print(os.path.dirname(ruamel.yaml.__file__))') \
			typeshed/2and3/ruamel/ ; \
	fi  # if minimally required ruamel.yaml version is 0.15.99 or greater, than the above can be removed
	MYPYPATH=$$MYPYPATH:typeshed/3:typeshed/2and3 mypy --disallow-untyped-calls \
		 --warn-redundant-casts \
		 schema_salad

mypyc: ${PYSOURCES}
	MYPYPATH=typeshed/2and3/:typeshed/3 SCHEMA_SALAD_USE_MYPYC=1 python setup.py test

pyupgrade: $(filter-out schema_salad/metaschema.py,${PYSOURCES})
	pyupgrade --exit-zero-even-if-changed --py36-plus $^

jenkins: FORCE
	rm -Rf env && virtualenv env
	. env/bin/activate ; \
	pip install -U setuptools pip wheel ; \
	${MAKE} install-dep coverage.html coverage.xml pydocstyle_report.txt \
		sloccount.sc pylint_report.txt
	if ! test -d env3 ; then virtualenv -p python3 env3 ; fi
	. env3/bin/activate ; \
	pip install -U setuptools pip wheel ; \
	${MAKE} install-dep ; \
	pip install -U -r mypy_requirements.txt ; ${MAKE} mypy

release-test: FORCE
	git diff-index --quiet HEAD -- || ( echo You have uncommited changes, please commit them and try again; false )
	PYVER=3 ./release-test.sh

release: release-test
	. testenv3_2/bin/activate && \
		testenv3_2/src/${PACKAGE}/setup.py sdist bdist_wheel
	. testenv3_2/bin/activate && \
		pip install twine && \
		twine upload testenv3_2/src/${PACKAGE}/dist/* && \
		git tag ${VERSION} && git push --tags

FORCE:

# Use this to print the value of a Makefile variable
# Example `make print-VERSION`
# From https://www.cmcrossroads.com/article/printing-value-makefile-variable
print-%  : ; @echo $* = $($*)
