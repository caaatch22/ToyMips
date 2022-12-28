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
	input [`RegBus]           mem_data_i,

	input                     LLbit_i,
	// bypass for LLbit 
	input                     wb_LLbit_we_i,
	input                     wb_LLbit_value_i,
         
	input                     cp0_reg_we_i,
	input [4:0]               cp0_reg_waddr_i,
	input [`RegBus]           cp0_reg_data_i,

	input [31:0]              excepttype_i,
	input                     is_in_delayslot_i,
	input [`RegBus]           cur_inst_addr_i,

	//CP0的各个寄存器的值，但不一定是最新的值，要防止回写阶段指令写CP0
	input [`RegBus]           cp0_status_i,
	input [`RegBus]           cp0_cause_i,
	input [`RegBus]           cp0_epc_i,

	//回写阶段的指令是否要写CP0，用来检测数据相关
  	input                     wb_cp0_reg_we,
	input [4:0]               wb_cp0_reg_waddr,
	input [`RegBus]           wb_cp0_reg_data,	

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
	output reg[`RegBus]       cp0_reg_data_o,

	output reg[31:0]          excepttype_o,
	output [`RegBus]          cp0_epc_o,
	output                    is_in_delayslot_o,
	
	output [`RegBus]          cur_inst_addr_o		
	
);

  wire [`RegBus] zero32;
  reg            mem_we;
  reg[`RegBus]   cp0_status;
  reg[`RegBus]   cp0_cause;
  reg[`RegBus]   cp0_epc;
  reg            LLbit;

  assign is_in_delayslot_o = is_in_delayslot_i;
  assign cur_inst_addr_o   = cur_inst_addr_i;
  assign cp0_epc_o = cp0_epc;

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

  // assign mem_we_o = mem_we;
  // if exception accur, no visit mem
  assign mem_we_o = mem_we & (~(|excepttype_o));
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
		whilo_o <= whilo_i;

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

  // get lastest cp0 status
  always @(*) begin
	if(rst == `RstEnable) begin
		cp0_status <= `ZeroWord;
	// data bypass
	end else if((wb_cp0_reg_we == `WriteEnable) && 
		        (wb_cp0_reg_waddr == `CP0_REG_STATUS ))begin
		cp0_status <= wb_cp0_reg_data;
	end else begin
		cp0_status <= cp0_status_i;
	end
  end
  
  // get lastest EPC
  always @ (*) begin
	if(rst == `RstEnable) begin
		cp0_epc <= `ZeroWord;
	// data bypass
	end else if((wb_cp0_reg_we == `WriteEnable) && 
				(wb_cp0_reg_waddr == `CP0_REG_EPC ))begin
		cp0_epc <= wb_cp0_reg_data;
	end else begin
		cp0_epc <= cp0_epc_i;
	end
  end	

  assign epc_o = cp0_epc;

  // get lastest cp0 cause
  always @ (*) begin
	if(rst == `RstEnable) begin
		cp0_cause <= `ZeroWord;
	end else if((wb_cp0_reg_we == `WriteEnable) && 
				(wb_cp0_reg_waddr == `CP0_REG_CAUSE ))begin
		// data bypass
		cp0_cause[9:8] <= wb_cp0_reg_data[9:8];
		cp0_cause[22] <= wb_cp0_reg_data[22];
		cp0_cause[23] <= wb_cp0_reg_data[23];
	end else begin
		cp0_cause <= cp0_cause_i;
	end
  end

 
  // determine excepttype
  always @ (*) begin
	if(rst == `RstEnable) begin
		excepttype_o <= `ZeroWord;
	end else begin
		excepttype_o <= `ZeroWord;	
		if(cur_inst_addr_i != `ZeroWord) begin
			if(( (cp0_cause[15:8] & (cp0_status[15:8])) != 8'h00) 
			  && (cp0_status[1] == 1'b0) 
			  && (cp0_status[0] == 1'b1)) begin
					excepttype_o <= 32'h00000001;        //interrupt
			end else if(excepttype_i[8] == 1'b1) begin
				excepttype_o <= 32'h00000008;        //syscall
			end else if(excepttype_i[9] == 1'b1) begin
				excepttype_o <= 32'h0000000a;        //inst_invalid
			end else if(excepttype_i[10] ==1'b1) begin
				excepttype_o <= 32'h0000000d;        //trap
			end else if(excepttype_i[11] == 1'b1) begin  //ov
				excepttype_o <= 32'h0000000c;
			end else if(excepttype_i[12] == 1'b1) begin  //返回指令
				excepttype_o <= 32'h0000000e;
			end
		end		
	end
  end	



endmodule