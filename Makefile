IVERILOG := iverilog
VVP := vvp

IVERILOG_FLAGS := -Wall -g2012 -Iinclude
VVP_FLAGS := -v -l sim/log

BUILD_DIR := build
VCD_DIR := sim
SRC_DIR := src
TB_DIR := tb

VERILOG_SOURCES := $(wildcard $(SRC_DIR)/*.sv)
TESTBENCHES := cache_controller_tb

.PHONY: all clean data docker
all: prepare $(TESTBENCHES)

prepare:
	mkdir -p $(BUILD_DIR)
	mkdir -p $(VCD_DIR)

data:
	python3 $(TB_DIR)/generate_data.py

$(BUILD_DIR)/%.out: $(TB_DIR)/%.sv $(VERILOG_SOURCES) | prepare
	@echo "Compiling $< (and dependencies) -> $@"
	$(IVERILOG) $(IVERILOG_FLAGS) -s $(*F) -o $@ $(VERILOG_SOURCES) $<

run_%: $(BUILD_DIR)/%.out
	echo "Running $(*F)"
	$(VVP) $< $(VVP_FLAGS) > $(VCD_DIR)/$*.log
	if [ -f $*.vcd ]; then mv $*.vcd $(VCD_DIR)/; fi

$(TESTBENCHES): %: run_%

docker:
	docker build -t cache-sim .
	docker run --rm cache-sim

clean:
	rm -rf $(BUILD_DIR) $(VCD_DIR)
