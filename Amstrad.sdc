derive_pll_clocks
derive_clock_uncertainty

set_multicycle_path -from {emu|u765|sbuf|*} -setup 2
set_multicycle_path -from {emu|u765|sbuf|*} -hold 1
set_multicycle_path -from {emu|u765|image_track_offsets_rtl_0|*} -setup 2
set_multicycle_path -from {emu|u765|image_track_offsets_rtl_0|*} -hold 1
set_multicycle_path -to   {emu|u765|i_*} -setup 2
set_multicycle_path -to   {emu|u765|i_*} -hold 1
set_multicycle_path -to   {emu|u765|i_*[*]} -setup 2
set_multicycle_path -to   {emu|u765|i_*[*]} -hold 1
set_multicycle_path -to   {emu|u765|pcn[*]} -setup 2
set_multicycle_path -to   {emu|u765|pcn[*]} -hold 1
set_multicycle_path -to   {emu|u765|ncn[*]} -setup 2
set_multicycle_path -to   {emu|u765|ncn[*]} -hold 1
set_multicycle_path -to   {emu|u765|state[*]} -setup 2
set_multicycle_path -to   {emu|u765|state[*]} -hold 1
set_multicycle_path -to   {emu|u765|status[*]} -setup 2
set_multicycle_path -to   {emu|u765|status[*]} -hold 1
set_multicycle_path -to   {emu|u765|i_rpm_time[*][*][*]} -setup 4
set_multicycle_path -to   {emu|u765|i_rpm_time[*][*][*]} -hold 3
