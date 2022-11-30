`include "defines.v"

module id_ex(

    input                         clk,
    input                         rst,

    input [5:0]                   stall, 
    input                         flush, 
	
	// message from instruction decode
    input [`AluOpBus]             id_aluop,
    input [`AluSelBus]            id_alusel,
    input [`RegBus]               id_reg1,
    input [`RegBus]               id_reg2,
    input [`RegAddrBus]           id_wd,
    input                         id_wreg,	
    
    input wire[`RegBus]           id_link_addr,
    input wire                    id_is_in_delayslot,
    input wire                    next_inst_in_delayslot_i,		

    input [`RegBus]               id_inst,   // for lw, sw	
    input [`RegBus]               id_cur_inst_addr,
    input [31: 0]                 id_excepttype,	
    
	// send to execute
    output reg[`AluOpBus]         ex_aluop,
    output reg[`AluSelBus]        ex_alusel,
    output reg[`RegBus]           ex_reg1,
    output reg[`RegBus]           ex_reg2,
    output reg[`RegAddrBus]       ex_wd,
    output reg                    ex_wreg,

    output reg[`RegBus]           ex_link_addr,
    output reg                    ex_is_in_delayslot,
    output reg                    is_in_delayslot_o,

    output reg[`RegBus]           ex_inst,

    output reg[`RegBus]           ex_cur_inst_addr,
    output reg[31: 0]             ex_excepttype	

);

  always @ (posedge clk) begin
    if (rst == `RstEnable) begin
        ex_aluop           <= `EXE_NOP_OP;
        ex_alusel          <= `EXE_RES_NOP;
        ex_reg1            <= `ZeroWord;
        ex_reg2            <= `ZeroWord;
        ex_wd              <= `NOPRegAddr;
        ex_wreg            <= `WriteDisable;
        ex_link_addr       <= `ZeroWord;
        ex_is_in_delayslot <= `NotInDelaySlot;
        is_in_delayslot_o  <= `NotInDelaySlot;		
        ex_inst            <= `ZeroWord;
        ex_excepttype      <= `ZeroWord;
        ex_cur_inst_addr   <= `ZeroWord;
    end else if(flush == `Flush) begin
        ex_aluop           <= `EXE_NOP_OP;
        ex_alusel          <= `EXE_RES_NOP;
        ex_reg1            <= `ZeroWord;
        ex_reg2            <= `ZeroWord;
        ex_wd              <= `NOPRegAddr;
        ex_wreg            <= `WriteDisable;
        ex_link_addr       <= `ZeroWord;
        ex_is_in_delayslot <= `NotInDelaySlot;
        is_in_delayslot_o  <= `NotInDelaySlot;		
        ex_inst            <= `ZeroWord;
        ex_excepttype      <= `ZeroWord;
        ex_cur_inst_addr   <= `ZeroWord;
    // for no delay slot, we block next inst
    end else if(id_is_in_delayslot == 1'b1) begin
        ex_aluop           <= `EXE_NOP_OP;
        ex_alusel          <= `EXE_RES_NOP;
        ex_reg1            <= `ZeroWord;
        ex_reg2            <= `ZeroWord;
        ex_wd              <= `NOPRegAddr;
        ex_wreg            <= `WriteDisable;
        ex_link_addr       <= `ZeroWord;
        ex_is_in_delayslot <= `NotInDelaySlot;
        is_in_delayslot_o  <= `NotInDelaySlot;		
        ex_inst            <= `ZeroWord;
        ex_excepttype      <= `ZeroWord;
        ex_cur_inst_addr   <= `ZeroWord;
    end else if(stall[2] == `Stop && stall[3] == `NoStop) begin
        ex_aluop           <= `EXE_NOP_OP;
        ex_alusel          <= `EXE_RES_NOP;
        ex_reg1            <= `ZeroWord;
        ex_reg2            <= `ZeroWord;
        ex_wd              <= `NOPRegAddr;
        ex_wreg            <= `WriteDisable;	
        ex_link_addr       <= `ZeroWord;
        ex_is_in_delayslot <= `NotInDelaySlot;	
        // is_in_delayslot_o  <= `NotInDelaySlot;	
        ex_inst            <= `ZeroWord;	
        ex_excepttype      <= `ZeroWord;
        ex_cur_inst_addr   <= `ZeroWord;		
		end else if(stall[2] == `NoStop) begin	
        ex_aluop           <= id_aluop;
        ex_alusel          <= id_alusel;
        ex_reg1            <= id_reg1;
        ex_reg2            <= id_reg2;
        ex_wd              <= id_wd;
        ex_wreg            <= id_wreg;		
        ex_link_addr       <= id_link_addr;
        ex_is_in_delayslot <= id_is_in_delayslot;
        is_in_delayslot_o  <= next_inst_in_delayslot_i;	
        ex_inst            <= id_inst;
        ex_excepttype      <= id_excepttype;
        ex_cur_inst_addr   <= id_cur_inst_addr;
      end
  end

  
endmodule