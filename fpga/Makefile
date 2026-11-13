# build for the Icepi Zero
#   make       -> khatam_v.bit  (do a make in the top folder first)

SOURCES = ../src/project.v ../src/cpu.v ../src/qspi.v ../src/gpu.v ../src/audio.v \
          top.v spi_bram.v pll.v dvi_out.v tmds_encoder.v

all: khatam_v.bit

# one byte per line, for $$readmemh
firmware.hex: ../build/starfall.bin
	od -An -tx1 -v $< | tr -s ' ' '\n' | sed '/^$$/d' > $@

khatam_v.json: $(SOURCES) firmware.hex
	yosys -q -p 'synth_ecp5 -top top -json $@' $(SOURCES)

khatam_v.config: khatam_v.json icepi-zero.lpf
	nextpnr-ecp5 --25k --package CABGA256 --lpf icepi-zero.lpf --json $< --textcfg $@

khatam_v.bit: khatam_v.config
	ecppack --compress $< $@

clean:
	rm -f khatam_v.json khatam_v.config khatam_v.bit firmware.hex

.PHONY: all clean
