# actually it's 4 MHz, but PLL gives warning
create_clock -period 10MHz [get_ports clk_in]

derive_pll_clocks -create_base_clocks

derive_clock_uncertainty