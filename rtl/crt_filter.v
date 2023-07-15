//------------------------------------------------------------------------------
//
// Extracted to separate entity, converted to verilog, optimized and tweaked
// (c) 2018 Sorgelig
//
//------------------------------------------------------------------------------
//
//    {@{@{@{@{@{@
//  {@{@{@{@{@{@{@{@  This code is covered by CoreAmstrad synthesis r005
//  {@    {@{@    {@  A core of Amstrad CPC 6128 running on MiST-board platform
//  {@{@{@{@{@{@{@{@
//  {@  {@{@{@{@  {@  CoreAmstrad is implementation of FPGAmstrad on MiST-board
//  {@{@        {@{@   Contact : renaudhelias@gmail.com
//  {@{@{@{@{@{@{@{@   @see http://code.google.com/p/mist-board/
//    {@{@{@{@{@{@     @see FPGAmstrad at CPCWiki
//
//------------------------------------------------------------------------------

// https://sourceforge.net/p/jemu/code/HEAD/tree/JEMU/src/jemu/system/cpc/GateArray.java

// altera message_off 10027
module crt_filter
(
	input      CLK,
	input      CE_4,
	input      HSYNC_I,
	input      VSYNC_I,
	output reg HSYNC_O,
	output reg VSYNC_O,
	output reg HBLANK,
	output reg VBLANK,
	output     SHIFT
);

wire resync = 1;
reg hs4,shift;
assign SHIFT = shift ^ hs4;


// generate HSync if original is absent for almost whole frame
reg hsync, no_hsync;
always @(posedge CLK) begin : hsyncgen
	reg [15:0] dcnt;
	reg [10:0] hsz, hcnt;

	reg old_vsync, old_hsync;
	reg no_hsync_next;
	
	if(CE_4) begin
		if(&dcnt) no_hsync_next <= 1; else dcnt <= dcnt + 1'd1;
		
		old_hsync <= HSYNC_I;
		if(~old_hsync & HSYNC_I) begin
			dcnt <= 0;
			if(no_hsync && !hsz) begin
				hsz <= dcnt[10:0];
				hsync <= 1;
				hcnt <= 0;
			end
		end
		
		if(no_hsync && hsz) begin
			hcnt <= hcnt + 1'd1;
			if(hcnt == 13) hsync <= 0;
			if(hcnt == hsz) begin
				hsync <= 1;
				hcnt <= 0;
			end
		end
		
		old_vsync <= VSYNC_I;
		if(~old_vsync & VSYNC_I) begin
			no_hsync <= no_hsync_next;
			no_hsync_next <= 0;
			hsz <= 0;
		end
	end

end

reg hsync_mask = 0;
// check for too frequent HSYNCs (S&KOH)
always @(posedge CLK) begin : hsyncfilt
	reg old_hsync;
	reg [8:0] line_time;

	if(CE_4) begin
		old_hsync <= HSYNC_I;
		if (hsync_mask) begin
			if (~&line_time) line_time <= line_time + 1'd1;
			if (!HSYNC_I & line_time >= 190) hsync_mask <= 0; // clear the mask after enough time
		end

		if (HSYNC_I & ~old_hsync & !hsync_mask) line_time <= 0; // new line detected
		if (~HSYNC_I & old_hsync & !hsync_mask) hsync_mask <= 1; // start to mask after the first hsync seen
	end
end

wire hsync_i = no_hsync ? hsync : (HSYNC_I & ~hsync_mask);


// Generate HSync,VSync for monitor
// HSync: delayed by 2us for set, immediate reset and limited by 4us.
// VSync: delayed by 2 lines for set, immediate reset and limited by 2 lines.
always @(posedge CLK) begin : syncgen
	reg       old_hsync;
	reg       old_vsync,old_vs;
	reg [8:0] hSyncCount;
	reg [9:0] hSyncCount2x;
	reg [8:0] hSyncSize;
	reg       hSyncReg;
	reg [3:0] vSyncCount;
	reg [1:0] syncs;
	reg [8:0] vSyncFlt;

	localparam HFLT_SZ = 50*4;
	localparam VFLT_SZ = 260;

	if(CE_4) begin
		old_hsync <= hsync_i;

		if(resync) begin
			if(~&hSyncCount) hSyncCount = hSyncCount + 1'd1;
			if(~old_hsync & hsync_i) old_vs <= VSYNC_I;

			//re-align restored hsync to the first hsync of vsync
			if((~old_vs & VSYNC_I & ~old_hsync & hsync_i) || (hSyncCount >= hSyncSize)) begin
				hSyncCount = 0;
				if(~old_hsync & hsync_i) hSyncReg <= 1;
			end
			
			// Calc line size from length of 2 first lines after VSync
			// 2 lines are needed to neutralize fake interlace video
			if(~&hSyncCount2x) hSyncCount2x = hSyncCount2x + 1'd1;
			if(~old_hsync & hsync_i) begin
				if(~VSYNC_I & ~&syncs) syncs = syncs + 1'd1;
				if(VSYNC_I) {syncs,hSyncCount2x} = 0;
				if(syncs == 2) hSyncSize <= hSyncCount2x[9:1];
			end
		end
		else begin
			if(hSyncCount < HFLT_SZ) hSyncCount = hSyncCount + 1'd1;
			else if(~old_hsync & hsync_i) begin
				hSyncCount = 0;
				hSyncReg <= 1;
			end
		end

		if(old_hsync & ~hsync_i & hSyncReg) begin
			hSyncReg <= 0;
			if(hSyncCount > 7*4) hs4 <= 0;
			if((hSyncCount >= 4*4-1) && (hSyncCount < 6*4-1)) begin
				if(hSyncCount == 4*4-1) hs4 <= 1;
				shift <= 1;
			end
		end

		if(hSyncCount == 2*4) begin
			HSYNC_O <= 1;
			shift <= 0;
			old_vsync <= VSYNC_I;
			
			if(~&vSyncFlt) vSyncFlt <= vSyncFlt + 1'd1;

			if(VSYNC_I) begin
				if(~old_vsync && (vSyncFlt > VFLT_SZ)) begin
					vSyncCount = 0;
					vSyncFlt <= 0;
				end
				else if(~&vSyncCount) vSyncCount = vSyncCount + 1'd1;
			end
			
			if(vSyncCount == 1) VSYNC_O <= 1;
			if(!vSyncCount || (vSyncCount == 3)) VSYNC_O <= 0;
		end

		//force VSYNC disable earlier
		if(~VSYNC_I) VSYNC_O <= 0;

		if(hSyncCount == 6*4) HSYNC_O <= 0;
	end
end

always @(posedge CLK) begin : blankgen

	localparam  BEGIN_VBORDER = 4 * 8 - 2;
	localparam  END_VBORDER = 37 * 8 + 6;

	localparam  BEGIN_HBORDER = 49;
	localparam  END_HBORDER = 241;

	reg old_vs;
	reg old_hs;

	reg [8:0] vborder;
	reg [8:0] hborder;

	if (CE_4) begin

		if(~&hborder) hborder <= hborder + 1'd1;
		old_hs <= HSYNC_O;
		if (~old_hs & HSYNC_O) begin
			hborder <= 0;
			HBLANK <= 1;

			if(~&vborder) vborder <= vborder + 1'd1;
			old_vs <= VSYNC_O;
			if(~old_vs & VSYNC_O) begin
				vborder <= 0;
				VBLANK <= 1;
			end
		end

		if(hborder == BEGIN_HBORDER) begin
			HBLANK <= 0;
			if(vborder == BEGIN_VBORDER) VBLANK <= 0;
		end
		
		if(hborder == END_HBORDER) begin
			HBLANK <= 1;
			if(vborder == END_VBORDER) VBLANK <= 1;
		end
	end
end

endmodule
