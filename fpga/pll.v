// 50 MHz in -> 125 MHz (TMDS shift clock) + 25 MHz (pixel clock)
// numbers came from: ecppll -i 50 -o 125 -s 25
`default_nettype none

module pll (
    input  wire clk_in,
    output wire clk_shift,
    output wire clk_pix,
    output wire locked
);

  (* FREQUENCY_PIN_CLKI="50" *)
  (* FREQUENCY_PIN_CLKOP="125" *)
  (* FREQUENCY_PIN_CLKOS="25" *)
  (* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
  EHXPLLL #(
      .PLLRST_ENA("DISABLED"),
      .INTFB_WAKE("DISABLED"),
      .STDBY_ENABLE("DISABLED"),
      .DPHASE_SOURCE("DISABLED"),
      .OUTDIVIDER_MUXA("DIVA"),
      .OUTDIVIDER_MUXB("DIVB"),
      .OUTDIVIDER_MUXC("DIVC"),
      .OUTDIVIDER_MUXD("DIVD"),
      .CLKI_DIV(2),
      .CLKOP_ENABLE("ENABLED"),
      .CLKOP_DIV(5),
      .CLKOP_CPHASE(4),
      .CLKOP_FPHASE(0),
      .CLKOS_ENABLE("ENABLED"),
      .CLKOS_DIV(25),
      .CLKOS_CPHASE(24),
      .CLKOS_FPHASE(0),
      .FEEDBK_PATH("CLKOP"),
      .CLKFB_DIV(5)
  ) pll_i (
      .RST(1'b0),
      .STDBY(1'b0),
      .CLKI(clk_in),
      .CLKOP(clk_shift),
      .CLKOS(clk_pix),
      .CLKFB(clk_shift),
      .CLKINTFB(),
      .PHASESEL0(1'b0),
      .PHASESEL1(1'b0),
      .PHASEDIR(1'b1),
      .PHASESTEP(1'b1),
      .PHASELOADREG(1'b1),
      .PLLWAKESYNC(1'b0),
      .ENCLKOP(1'b0),
      .LOCK(locked)
  );

endmodule
