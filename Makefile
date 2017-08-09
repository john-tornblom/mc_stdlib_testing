ifndef MC_STDLIB_DIR
    $(error MC_STDLIB_DIR is undefined)
endif

ifndef UNIT_TESTING_DIR
    $(error UNIT_TESTING_DIR is undefined)
endif

ifndef BRIDGEPOINT_DIR
    $(error BRIDGEPOINT_DIR is undefined)
endif

ROOTDIR  := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
PROJECTS := $(MC_STDLIB_DIR) $(UNIT_TESTING_DIR) $(ROOTDIR)
MARKINGS := $(ROOTDIR)/mc3020/marking
SOURCES  := $(MC_STDLIB_DIR)/mc3020/src $(UNIT_TESTING_DIR)/mc3020/src

#
# Don't modify below unless you know what you are doing
#

BP       ?= $(BRIDGEPOINT_DIR)/bridgepoint
MC3020   ?= $(BRIDGEPOINT_DIR)/tools/mc/bin/mc3020.py
CC       ?= gcc
CFLAGS   ?= -g -O0 -fprofile-arcs -ftest-coverage --coverage
LDFLAGS  ?= -lc -lgcov

SRC_FILES   := $(shell find $(SOURCES) -name *.c)
MARK_FILES  := $(shell find $(MARKINGS) -name *.mark)
MODEL_FILES := $(shell find $(PROJECTS) -name *.xtuml)

TARGET := $(shell ls $(ROOTDIR)/models)
GENDIR := $(ROOTDIR)/gen/code_generation
COVDIR := $(GENDIR)/_cov

CDTAPP := org.eclipse.cdt.managedbuilder.core.headlessbuild
TMPWS  := $(shell mktemp -u)
WS     := $(GENDIR)/_ws
SRCDIR := $(GENDIR)/_ch
SQL    := $(GENDIR)/$(TARGET).sql
BIN    := $(ROOTDIR)/$(TARGET)

COPIES := $(notdir $(SRC_FILES))
COPIES := $(addprefix $(SRCDIR)/, $(COPIES))

all: $(BIN)

$(WS):
	@$(foreach PROJECT,$(PROJECTS),$(BP) -nosplash -data $(TMPWS) -application $(CDTAPP) -import $(PROJECT);)
	@mkdir -p $(GENDIR)
	@mv $(TMPWS) $@

$(SQL): $(WS) $(MODEL_FILES)
	@$(BP) -nosplash -data $(WS) -application org.xtuml.bp.cli.Build -project $(TARGET) -prebuildOnly

$(SRCDIR): $(SQL) $(MARK_FILES)
	@$(MC3020) -m $(MARKINGS) -o $(GENDIR) $(SQL)
	@rm -f $(COPIES)
	@touch $@

$(BIN): $(SRC_FILES) $(SRCDIR)
	@cd $(GENDIR); $(CC) -o $@ -I$(SRCDIR) $(CFLAGS) $(SRC_FILES) $(wildcard $(SRCDIR)/*.c) $(LDFLAGS)

.PHONEY:
clean:
	@rm -f $(BIN)
	@rm -rf $(GENDIR)

test: $(BIN)
	@$(BIN)
	@lcov -q --directory $(GENDIR) --capture --output-file $(GENDIR)/$(TARGET).gcov.info
	@genhtml -q --output-directory $(COVDIR) $(GENDIR)/$(TARGET).gcov.info
	@echo "INFO:Coverage results are available at $(COVDIR)/index.html"
