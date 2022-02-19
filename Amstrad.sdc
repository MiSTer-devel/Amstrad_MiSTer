derive_pll_clocks
derive_clock_uncertainty

set_multicycle_path -from {emu|u765|image_track_offsets_rtl_0|*} -setup 2
set_multicycle_path -from {emu|u765|image_track_offsets_rtl_0|*} -hold 1
set_multicycle_path -to   {emu|u765|i_*} -setup 2
set_multicycle_path -to   {emu|u765|i_*} -hold 1
set_multicycle_path -to   {emu|u765|i_*[*]} -setup 2
set_multicycle_path -to   {emu|u765|i_*[*]} -hold 1
