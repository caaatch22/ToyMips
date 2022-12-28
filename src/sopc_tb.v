`include "defines.v"
`include "sopc.v"
`timescale 1ns/1ps

module sopc_tb();

  reg     CLOCK_50;
  reg     rst;
  
  initial begin
      $display("start a clock pulse"); 
      $dumpfile("wave.vcd");
      $dumpvars(0, sopc_tb);    
  end
  initial begin
    CLOCK_50 = 1'b0;
    forever #10 CLOCK_50 = ~CLOCK_50;
  end
      
  initial begin
    rst = `RstEnable;
    #195 rst= `RstDisable;
    #10000 $finish;
  end
       
    sopc sopc0(
		.clk(CLOCK_50),
		.rst(rst)	
	);

endmodule