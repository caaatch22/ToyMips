`include "defines.v"

module hilo_reg(

    input             clk,
    input             rst,
    
    // write port
    input             we,
    input [`RegBus]   hi_i,
    input [`RegBus]   lo_i,
	
	// read port
	output reg[`RegBus] hi_o,
	output reg[`RegBus] lo_o
	
);

  always @ (posedge clk) begin
    if (rst == `RstEnable) begin
        hi_o <= `ZeroWord;
        lo_o <= `ZeroWord;
    end else if((we == `WriteEnable)) begin
        hi_o <= hi_i;
        lo_o <= lo_i;
        // for debug
        $display("reg:hi<=%h",hi_i);
        $display("reg:lo<=%h",lo_i);
    end
  end

endmodule