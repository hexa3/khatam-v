# build + flash for the Icepi Zero

SOURCES = ../src/project.v ../src/cpu.v ../src/adder.v ../src/qspi.v ../src/gpu.v \
          top.v spi_bram.v pll.v dvi_out.v tmds_encoder.v

all: prog

firmware.hex: ../build/hello.hex
	cp $< $@

../build/hello.hex:
	$(MAKE) -C .. build/hello.hex

khatam_v.json: $(SOURCES) firmware.hex
	yosys -q -p 'synth_ecp5 -top top -json $@' $(SOURCES)

khatam_v.config: khatam_v.json icepi-zero.lpf
	nextpnr-ecp5 --25k --package CABGA256 --lpf icepi-zero.lpf --json $< --textcfg $@

khatam_v.bit: khatam_v.config
	ecppack --compress $< $@

prog: khatam_v.bit
	openFPGALoader -b icepi-zero $<

clean:
	rm -f khatam_v.json khatam_v.config khatam_v.bit firmware.hex

.PHONY: all prog clean
