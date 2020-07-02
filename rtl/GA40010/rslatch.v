// simulate an RS flip-flop in the 'clock' domain

module rslatch (
    input clock,
    input s,    // set
    input r,    // reset
    output reg [WIDTH-1:0] q  // output
);

parameter PRIO_SET = 1; // set is "stronger" by default
parameter WIDTH = 1;

reg [WIDTH-1:0] val_reg;

always @(*) begin
	if (PRIO_SET)
		if (s)
			q = 1;
		else if (r)
			q = 0;
		else
			q = val_reg;
	else
		if (r)
			q = 0;
		else if (s)
			q = 1;
		else
			q = val_reg;

end

always @(posedge clock) begin
    val_reg <= q;
end

endmodule