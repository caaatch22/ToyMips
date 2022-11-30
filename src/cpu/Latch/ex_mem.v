`include "defines.v"

module ex_mem(

	input clk,
	input rst,
	
	inout [5:0]              stall,
	
	// message from execution 	
	input [`RegAddrBus]      ex_wd,
	input                    ex_wreg,
	input [`RegBus]			 ex_wdata, 	
	input [`RegBus]          ex_hi,
	input [`RegBus]          ex_lo,
	input                    ex_whilo, 

	// for store, load
    input [`AluOpBus]        ex_aluop,
	input [`RegBus]          ex_mem_addr,
	input [`RegBus]          ex_reg2,

	// for cp0
	input wire               ex_cp0_reg_we,
	input wire[4:0]          ex_cp0_reg_waddr,
	input wire[`RegBus]      ex_cp0_reg_data,	

	// send to mem
	output reg[`RegAddrBus]  mem_wd,
	output reg               mem_wreg,
	output reg[`RegBus]		 mem_wdata,
	output reg[`RegBus]      mem_hi,
	output reg[`RegBus]      mem_lo,
	output reg               mem_whilo,

	// for store and load
	output reg[`AluOpBus]    mem_aluop,
	output reg[`RegBus]      mem_mem_addr,
	output reg[`RegBus]      mem_reg2,

	output reg               mem_cp0_reg_we,
	output reg[4:0]          mem_cp0_reg_waddr,
	output reg[`RegBus]      mem_cp0_reg_data
	
);


  always @ (posedge clk) begin
    if (rst == `RstEnable) begin
        mem_wd            <= `NOPRegAddr;
        mem_wreg          <= `WriteDisable;
        mem_wdata         <= `ZeroWord;
        mem_aluop         <= `EXE_NOP_OP;
        mem_mem_addr      <= `ZeroWord;
        mem_reg2          <= `ZeroWord;
		mem_cp0_reg_we    <= `WriteDisable;
		mem_cp0_reg_waddr <= 5'b00000;
		mem_cp0_reg_data  <= `ZeroWord;
	end else if(stall[3] == `Stop && stall[4] == `NoStop) begin
        mem_wd            <= `NOPRegAddr;
        mem_wreg          <= `WriteDisable;
        mem_wdata         <= `ZeroWord;
        mem_aluop         <= `EXE_NOP_OP;
        mem_mem_addr      <= `ZeroWord;
        mem_reg2          <= `ZeroWord;
		mem_cp0_reg_we    <= `WriteDisable;
		mem_cp0_reg_waddr <= 5'b00000;
		mem_cp0_reg_data  <= `ZeroWord;
    end else if(stall[3] == `NoStop) begin
        mem_wd            <= ex_wd;
        mem_wreg          <= ex_wreg;
        mem_wdata         <= ex_wdata;
		mem_aluop         <= ex_aluop;
		mem_mem_addr      <= ex_mem_addr;
		mem_reg2          <= ex_reg2;	
		mem_cp0_reg_we    <= ex_cp0_reg_we;
		mem_cp0_reg_waddr <= ex_cp0_reg_waddr;
		mem_cp0_reg_data  <= ex_cp0_reg_data;	
	end
  end      

endmodule