`include "defines.v"

module mem(

	input rst,

	// message from execution
	input [`RegAddrBus]       wd_i,
	input                     wreg_i,
	input [`RegBus]           wdata_i,
	input [`RegBus]           hi_i,
	input [`RegBus]           lo_i,
	input                     whilo_i,

    input [`AluOpBus]         aluop_i,
	input [`RegBus]           mem_addr_i,
	input [`RegBus]           reg2_i,
	
	// received from mem 
	input wire[`RegBus]       mem_data_i,

	input wire                LLbit_i,
	// bypass for LLbit 
	input wire                wb_LLbit_we_i,
	input wire                wb_LLbit_value_i,

	input wire                cp0_reg_we_i,
	input wire[4:0]           cp0_reg_waddr_i,
	input wire[`RegBus]       cp0_reg_data_i,

	// send to write back
	output reg[`RegAddrBus]   wd_o,
	output reg                wreg_o,
	output reg[`RegBus]       wdata_o,
	output reg[`RegBus]       hi_o,
	output reg[`RegBus]       lo_o,
	output reg                whilo_o,


	// interact with mem
	output reg[`RegBus]       mem_addr_o,
	output                    mem_we_o,
	output reg[3:0]           mem_sel_o,
	output reg[`RegBus]       mem_data_o,
	output reg                mem_ce_o,

	output reg                LLbit_we_o,
	output reg                LLbit_value_o,

	output reg                cp0_reg_we_o,
	output reg[4:0]           cp0_reg_waddr_o,
	output reg[`RegBus]       cp0_reg_data_o
	
);

  wire [`RegBus] zero32;
  reg            mem_we;

  reg            LLbit;

  always @(*) begin
	if(rst == `RstEnable) begin
		LLbit <= 1'b0;
	end else begin
		if(wb_LLbit_we_i) begin
			LLbit <= wb_LLbit_value_i;
		end else begin
			LLbit <= LLbit_i;
		end
	end
  end

  assign mem_we_o = mem_we;
  assign zero32   = `ZeroWord;
	
  always @ (*) begin
    if(rst == `RstEnable) begin
        wd_o    <= `NOPRegAddr;
        wreg_o  <= `WriteDisable;
        wdata_o <= `ZeroWord;
		hi_o    <= `ZeroWord;
		lo_o    <= `ZeroWord;
		whilo_o <= `WriteDisable;

		mem_addr_o      <= `ZeroWord;
		mem_we          <= `WriteDisable;
		mem_sel_o       <= 4'b0000;
		mem_data_o      <= `ZeroWord;
		mem_ce_o        <= `ChipDisable;
		LLbit_we_o      <= 1'b0;
		LLbit_value_o   <= 1'b0;		
		
		cp0_reg_we_o    <= `WriteDisable;
		cp0_reg_waddr_o <= 5'b00000;
		cp0_reg_data_o  <= `ZeroWord;	
    end else begin
        wd_o    <= wd_i;
        wreg_o  <= wreg_i;
        wdata_o <= wdata_i;
		hi_o    <= hi_i;
		lo_o    <= lo_i;
		whilo_o <= `WriteEnable;

		mem_we     <= `WriteDisable;
		mem_addr_o <= `ZeroWord;
		mem_sel_o  <= 4'b1111;
		mem_ce_o   <= `ChipDisable;

		LLbit_we_o      <= 1'b0;
		LLbit_value_o   <= 1'b0;		
		
		cp0_reg_we_o    <= cp0_reg_we_i;
		cp0_reg_waddr_o <= cp0_reg_waddr_i;
		cp0_reg_data_o  <= cp0_reg_data_i;
		
		case (aluop_i) 
		`EXE_LW_OP: begin
			mem_addr_o <= mem_addr_i;
			mem_we     <= `WriteDisable;
			wdata_o    <= mem_data_i;
			mem_sel_o  <= 4'b1111;
			mem_ce_o   <= `ChipEnable;	
		end
		`EXE_SW_OP:  begin
			mem_addr_o <= mem_addr_i;
			mem_we     <= `WriteEnable;
			mem_data_o <= reg2_i;
			mem_sel_o  <= 4'b1111;	
			mem_ce_o   <= `ChipEnable;
		end
		`EXE_LL_OP: begin
			mem_addr_o <= mem_addr_i;
			mem_we        <= `WriteEnable;
			mem_data_o    <= mem_data_i;
			mem_sel_o     <= 4'b1111;	
			mem_ce_o      <= `ChipEnable;
			LLbit_we_o    <= 1'b1;
			LLbit_value_o <= 1'b1;
		end
		`EXE_SC_OP:		begin
			if(LLbit == 1'b1) begin
				LLbit_we_o    <= 1'b1;
				LLbit_value_o <= 1'b0;
				mem_addr_o    <= mem_addr_i;
				mem_we        <= `WriteEnable;
				mem_data_o    <= reg2_i;
				wdata_o       <= 32'b1;
				mem_sel_o     <= 4'b1111;		
				mem_ce_o      <= `ChipEnable;				
			end else begin
				wdata_o       <= `ZeroWord;
			end
		end	
		endcase
		
	end
  end    
			

endmodule