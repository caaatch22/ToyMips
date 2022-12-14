module ex (
    input rst,

    input [`AluOpBus]         aluop_i,
    input [`AluSelBus]        alusel_i,
    input [`RegBus]           reg1_i,
    input [`RegBus]           reg2_i,
    input [`RegAddrBus]       wd_i,
    input                     wreg_i,

    input                     is_in_delayslot_i,
    input [`RegBus]           link_addr_i,

    input [`RegBus]           inst_i,            // for lw, sw

	input [31:0]              excepttype_i,
	input [`RegBus]           cur_inst_addr_i,

    // from HI、LO register
    input [`RegBus]           hi_i,
    input [`RegBus]           lo_i,

	// WB pahse HI、LO，bypass for hi, lo (mthi, mtlo)
    // mthi $1   # WB
    // mthi $2   # MEM
    // mfhi $3   # EX
	input [`RegBus]           wb_hi_i,
	input [`RegBus]           wb_lo_i,
	input                     wb_whilo_i,  // (signal)
	input [`RegBus]           mem_hi_i,
	input [`RegBus]           mem_lo_i,
	input                     mem_whilo_i,

    // forward from mem, wb to solve hazard of cp0
    input                     mem_cp0_reg_we,
    input [4:0]               mem_cp0_reg_waddr,
    input [`RegBus]           mem_cp0_reg_data,
    input                     wb_cp0_reg_we,
    input [4:0]               wb_cp0_reg_waddr,
    input [`RegBus]           wb_cp0_reg_data,

    // connect with CP0 
    input [`RegBus]           cp0_reg_data_i,
    output reg[4:0]           cp0_reg_raddr_o,

    // connect with module div
	input [`DoubleRegBus]     div_result_i,
	input                     div_ready_i,

    // execution result
    output reg[`RegAddrBus]   wd_o,
    output reg                wreg_o,
    output reg[`RegBus]       wdata_o,

    // about hilo_reg
	output reg[`RegBus]       hi_o,
	output reg[`RegBus]       lo_o,
	output reg                whilo_o,

    // for load, store
    output [`AluOpBus]        aluop_o,
    output [`RegBus]          mem_addr_o,
    output [`RegBus]          reg2_o,

    output reg[`RegBus]       div_opdata1_o,
    output reg[`RegBus]       div_opdata2_o,
    output reg                div_start_o,
    output reg                signed_div_o,

    output reg                cp0_reg_we_o,
    output reg[4:0]           cp0_reg_waddr_o,
    output reg[`RegBus]       cp0_reg_data_o,

	output [31:0]             excepttype_o,
	output                    is_in_delayslot_o,
	output [`RegBus]          cur_inst_addr_o,	

    output reg                stallreq

);

  reg[`RegBus]        logic_res;
  reg[`RegBus]        shift_res;
  reg[`RegBus]        move_res;
  reg[`DoubleRegBus]  mul_res;
  reg[`RegBus]        arithmetic_res;
  reg[`RegBus]        HI;
  reg[`RegBus]        LO;

  wire                sum_overflow;
  wire                reg1_eq_reg2;
  wire                reg1_lt_reg2;

  wire[`RegBus]       reg2_i_complement;  // complement of second operation num used in sub
  wire[`RegBus]       reg1_i_not;         // ~reg1  
  wire[`RegBus]       sum_res;            // sum of add
  wire[`RegBus]       opdata1_mult;
  wire[`RegBus]       opdata2_mult;
  wire[`DoubleRegBus] hilo_tmp;

  reg                 stallreq_for_div;

  reg                 trapassert;
  reg                 ovassert;
 
 // for load, store
  assign aluop_o = aluop_i;
  // reg1_i is the base reg for lw,sw
  assign mem_addr_o = reg1_i + {{16{inst_i[15]}}, inst_i[15:0]};
  assign reg2_o  = reg2_i;

  assign excepttype_o      = {excepttype_i[31:12],ovassert,trapassert,excepttype_i[9:8],8'h00};
  assign is_in_delayslot_o = is_in_delayslot_i;
  assign cur_inst_addr_o   = cur_inst_addr_i;

  // phase 1: ALUop
  
  // logic_res
  always @(*) begin
    if(rst == `RstEnable) begin
        logic_res <= `ZeroWord;
    end else begin
        case (aluop_i)
            `EXE_OR_OP:   logic_res <= reg1_i | reg2_i;
            `EXE_AND_OP:  logic_res <= reg1_i & reg2_i;
            `EXE_XOR_OP:  logic_res <= reg1_i ^ reg2_i;
            `EXE_NOR_OP:  logic_res <= ~(reg1_i | reg2_i);
            default:  logic_res <= `ZeroWord;
        endcase
    end
  end
 
  // shift_res;
  always @ (*) begin
    if (rst == `RstEnable) begin
        shift_res <= `ZeroWord;
    end else begin
        case (aluop_i)
            `EXE_SLL_OP: shift_res <= reg2_i << reg1_i[4:0];
            `EXE_SRL_OP: shift_res <= reg2_i >> reg1_i[4:0];
            `EXE_SRA_OP: shift_res <= $signed(reg2_i) >>> reg1_i[4:0];
            default: shift_res <= `ZeroWord;
            endcase
        end
    end

    
	assign reg2_i_complement = ((aluop_i == `EXE_SUB_OP) || 
                                (aluop_i == `EXE_SUBU_OP) ||
						        (aluop_i == `EXE_SLT_OP)) ?
						        (~reg2_i) + 1 : reg2_i;

	assign sum_res = reg1_i + reg2_i_complement;										 
    // debug
    // always @(*) begin
    //     if(aluop_i == `EXE_ADD_OP) begin
    //         $display("reg1:%h, reg2_i:%h, reg2_i_comp:%h, sum = %h",reg1_i, reg2_i, reg2_i_complement, sum_res);
    //     end
    // end

    // sum overflow ? 
    // 1. reg1_i > 0, reg2_i_complement > 0, but sum of them < 0
    // 2. reg1_i < 0, reg2_i_complement < 0, but sum of them > 0
	assign sum_overflow = ((!reg1_i[31] && !reg2_i_complement[31]) &&   sum_res[31]) ||
						  (( reg1_i[31] &&  reg2_i_complement[31]) && (!sum_res[31]));  
							
	assign reg1_lt_reg2 = ((aluop_i == `EXE_SLT_OP)) ?
												 ((reg1_i[31] && !reg2_i[31]) || 
												 (!reg1_i[31] && !reg2_i[31] && sum_res[31])||
			                   (reg1_i[31] && reg2_i[31] && sum_res[31]))
			                   :	(reg1_i < reg2_i);
  
    assign reg1_i_not = ~reg1_i;
  
    // arithmetic_res;
    always @ (*) begin
        if (rst == `RstEnable) arithmetic_res = `ZeroWord;
        else begin
            case (aluop_i)
            `EXE_ADD_OP, `EXE_ADDU_OP, `EXE_ADDI_OP, `EXE_ADDIU_OP, `EXE_SUB_OP, `EXE_SUBU_OP: begin
                arithmetic_res = sum_res;
            end
            `EXE_SLT_OP: begin
                if (reg1_i[31] & ~reg2_i[31])      arithmetic_res = 1'b1;
                else if (~reg1_i[31] & reg2_i[31]) arithmetic_res = 1'b0;
                else arithmetic_res = sum_res[31];
            end
            `EXE_SLTU_OP: arithmetic_res = reg1_i < reg2_i;
            `EXE_CLZ_OP: begin
                arithmetic_res = reg1_i[31] ? 0 : reg1_i[30] ? 1 : reg1_i[29] ? 2 :
													 reg1_i[28] ? 3 : reg1_i[27] ? 4 : reg1_i[26] ? 5 :
													 reg1_i[25] ? 6 : reg1_i[24] ? 7 : reg1_i[23] ? 8 : 
													 reg1_i[22] ? 9 : reg1_i[21] ? 10 : reg1_i[20] ? 11 :
													 reg1_i[19] ? 12 : reg1_i[18] ? 13 : reg1_i[17] ? 14 : 
													 reg1_i[16] ? 15 : reg1_i[15] ? 16 : reg1_i[14] ? 17 : 
													 reg1_i[13] ? 18 : reg1_i[12] ? 19 : reg1_i[11] ? 20 :
													 reg1_i[10] ? 21 : reg1_i[9] ? 22 : reg1_i[8] ? 23 : 
													 reg1_i[7] ? 24 : reg1_i[6] ? 25 : reg1_i[5] ? 26 : 
													 reg1_i[4] ? 27 : reg1_i[3] ? 28 : reg1_i[2] ? 29 : 
													 reg1_i[1] ? 30 : reg1_i[0] ? 31 : 32 ;
			end
			`EXE_CLO_OP: begin
			     arithmetic_res = ~reg1_i[31] ? 0 : ~reg1_i[30] ? 1 : ~reg1_i[29] ? 2 :
													~reg1_i[28] ? 3 : ~reg1_i[27] ? 4 : ~reg1_i[26] ? 5 :
													~reg1_i[25] ? 6 : ~reg1_i[24] ? 7 : ~reg1_i[23] ? 8 : 
													~reg1_i[22] ? 9 : ~reg1_i[21] ? 10 : ~reg1_i[20] ? 11 :
													~reg1_i[19] ? 12 : ~reg1_i[18] ? 13 : ~reg1_i[17] ? 14 : 
													~reg1_i[16] ? 15 : ~reg1_i[15] ? 16 : ~reg1_i[14] ? 17 : 
													~reg1_i[13] ? 18 : ~reg1_i[12] ? 19 : ~reg1_i[11] ? 20 :
													~reg1_i[10] ? 21 : ~reg1_i[9] ? 22 : ~reg1_i[8] ? 23 : 
													~reg1_i[7] ? 24 : ~reg1_i[6] ? 25 : ~reg1_i[5] ? 26 : 
													~reg1_i[4] ? 27 : ~reg1_i[3] ? 28 : ~reg1_i[2] ? 29 : 
													~reg1_i[1] ? 30 : ~reg1_i[0] ? 31 : 32 ;
			end
            default: arithmetic_res = `ZeroWord;
            endcase
        end
    end

    // for mul
    //取得乘法操作的操作数，如果是有符号除法且操作数是负数，那么取反加一
	assign opdata1_mult = (((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP))
							&& (reg1_i[31] == 1'b1)) ? (~reg1_i + 1) : reg1_i;

    assign opdata2_mult = (((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP))
							&& (reg2_i[31] == 1'b1)) ? (~reg2_i + 1) : reg2_i;		

    assign hilo_tmp = opdata1_mult * opdata2_mult;																				

	always @ (*) begin
		if(rst == `RstEnable) begin
			mul_res <= {`ZeroWord,`ZeroWord};
		end else if ((aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MUL_OP))begin
			if(reg1_i[31] ^ reg2_i[31] == 1'b1) begin
				mul_res <= ~hilo_tmp + 1;
			end else begin
			  mul_res <= hilo_tmp;
			end
		end else begin
			mul_res <= hilo_tmp;
		end
	end

    // trap
    always @ (*) begin
		if(rst == `RstEnable) begin
			trapassert <= `TrapNotAssert;
		end else begin
			trapassert <= `TrapNotAssert;
			case (aluop_i)
			    `EXE_TEQ_OP, `EXE_TEQI_OP: begin
					if(reg1_i == reg2_i) begin
						trapassert <= `TrapAssert;
					end
				end
				`EXE_TGE_OP, `EXE_TGEI_OP, `EXE_TGEIU_OP, `EXE_TGEU_OP: begin
					if(~reg1_lt_reg2) begin
						trapassert <= `TrapAssert;
					end
				end
				`EXE_TLT_OP, `EXE_TLTI_OP, `EXE_TLTIU_OP, `EXE_TLTU_OP: begin
					if(reg1_lt_reg2) begin
						trapassert <= `TrapAssert;
					end
				end
				`EXE_TNE_OP, `EXE_TNEI_OP: begin
					if(reg1_i != reg2_i) begin
						trapassert <= `TrapAssert;
					end
				end
				default: begin
					trapassert <= `TrapNotAssert;
				end
			endcase
		end
	end

    // get HI, LO with bypass
	always @ (*) begin
		if(rst == `RstEnable) begin
			{HI,LO} <= {`ZeroWord,`ZeroWord};
        // mem 与 wb有先后顺序，优先mem，因为这是上一条
		end else if(mem_whilo_i == `WriteEnable) begin   
			{HI,LO} <= {mem_hi_i,mem_lo_i};
		end else if(wb_whilo_i == `WriteEnable) begin
			{HI,LO} <= {wb_hi_i,wb_lo_i};
		end else begin
			{HI,LO} <= {hi_i,lo_i};			
		end
	end	
  
  // move_res
  always @(*) begin
    if (rst == `RstEnable) begin
        move_res <= `ZeroWord;
    end else begin
        move_res <= `ZeroWord;
        case (aluop_i)
            `EXE_MFHI_OP: move_res <= HI;
            `EXE_MFLO_OP: move_res <= LO;
            `EXE_MOVZ_OP: move_res <= reg1_i;
            `EXE_MOVZ_OP: move_res <= reg1_i;
            `EXE_MFC0_OP: begin
                cp0_reg_raddr_o    <= inst_i[15:11];
                move_res           <= cp0_reg_data_i;
                if( mem_cp0_reg_we == `WriteEnable &&
                    mem_cp0_reg_waddr == inst_i[15:11] ) begin
	   			    move_res       <= mem_cp0_reg_data;
                end else if( wb_cp0_reg_we == `WriteEnable &&
                            wb_cp0_reg_waddr == inst_i[15:11] ) begin
	   				move_res       <= wb_cp0_reg_data;
	   		    end
            end  	
	   	default : begin
	   	end
        endcase
    end
  end
  

  // for div, divu
  always @(*) begin
    if(rst == `RstEnable) begin
        stallreq_for_div <= `NoStop;
        div_opdata1_o    <= `ZeroWord;
        div_opdata2_o    <= `ZeroWord;
        div_start_o      <= `DivStop;
        signed_div_o     <= 1'b0;
    end else begin
        stallreq_for_div <= `NoStop;
        div_opdata1_o    <= `ZeroWord;
        div_opdata2_o    <= `ZeroWord;
        div_start_o      <= `DivStop;
        signed_div_o     <= 1'b0;
    end
    case (aluop_i)
        `EXE_DIV_OP: begin
            if(div_ready_i == `DivResultNotReady) begin
                div_opdata1_o    <= reg1_i;
                div_opdata2_o    <= reg2_i;
                div_start_o      <= `DivStart;
                signed_div_o     <= 1'b1;
                stallreq_for_div <= `Stop;
            end else if(div_ready_i == `DivResultReady) begin
                div_opdata1_o    <= reg1_i;
                div_opdata2_o    <= reg2_i;
                div_start_o      <= `DivStop;
                signed_div_o     <= 1'b1;
                stallreq_for_div <= `NoStop;
            end else begin	
                div_opdata1_o    <= `ZeroWord;
                div_opdata2_o    <= `ZeroWord;
                div_start_o      <= `DivStop;
                signed_div_o     <= 1'b0;
                stallreq_for_div <= `NoStop;
            end
        end
        `EXE_DIVU_OP: begin
            if(div_ready_i == `DivResultNotReady) begin
                div_opdata1_o    <= reg1_i;
                div_opdata2_o    <= reg2_i;
                div_start_o      <= `DivStart;
                signed_div_o     <= 1'b0;
                stallreq_for_div <= `Stop;
            end else if(div_ready_i == `DivResultReady) begin
                div_opdata1_o    <= reg1_i;
                div_opdata2_o    <= reg2_i;
                div_start_o      <= `DivStop;
                signed_div_o     <= 1'b0;
                stallreq_for_div <= `NoStop;
            end else begin	
                div_opdata1_o    <= `ZeroWord;
                div_opdata2_o    <= `ZeroWord;
                div_start_o      <= `DivStop;
                signed_div_o     <= 1'b0;
                stallreq_for_div <= `NoStop;
            end
        end
    endcase
    
  end

  always @(*) begin
    stallreq = stallreq_for_div;
  end

  // phase 2: ALUsel
  always @ (*) begin
    wd_o <= wd_i;	 
	if(((aluop_i == `EXE_ADD_OP) || (aluop_i == `EXE_ADDI_OP) || 
	   (aluop_i == `EXE_SUB_OP)) && (sum_overflow == 1'b1)) begin
	 	wreg_o   <= `WriteDisable;
        ovassert <= 1'b1;
	 end else begin
	  wreg_o     <= wreg_i;
      ovassert   <= 1'b0;
     end

    case (alusel_i) 
        `EXE_RES_LOGIC:       wdata_o <= logic_res;
        `EXE_RES_SHIFT:       wdata_o <= shift_res;
        `EXE_RES_MOVE:        wdata_o <= move_res;
        `EXE_RES_ARITHMETIC:  wdata_o <= arithmetic_res;
        `EXE_RES_MUL:         wdata_o <= mul_res[31: 0];
        `EXE_RES_JUMP_BRANCH: wdata_o <= link_addr_i;
        default:              wdata_o <= `ZeroWord;
	 endcase
  end	

  always @(*) begin
    if(rst == `RstEnable) begin
        whilo_o <= `WriteDisable;
        hi_o    <= `ZeroWord;
        lo_o    <= `ZeroWord;
    end else if( (aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MULTU_OP)) begin
		whilo_o <= `WriteEnable;
		hi_o    <= mul_res[63:32];
	    lo_o    <= mul_res[31:0];		
    end else if( (aluop_i == `EXE_DIV_OP) || (aluop_i == `EXE_DIVU_OP)) begin
        whilo_o <= `WriteEnable;
        hi_o    <= div_result_i[63:32];
        lo_o    <= div_result_i[31: 0];
    end else if(aluop_i == `EXE_MTLO_OP) begin
        whilo_o <= `WriteEnable;
        hi_o    <= HI;
        lo_o    <= reg1_i;
    end else if(aluop_i == `EXE_MTHI_OP) begin
        whilo_o <= `WriteEnable;
        hi_o    <= reg1_i;
        lo_o    <= LO;
    end else begin
        whilo_o <= `WriteDisable;
        hi_o    <= `ZeroWord;
        lo_o    <= `ZeroWord;
    end
  end

 always @ (*) begin
    if(rst == `RstEnable) begin
	    cp0_reg_waddr_o <= 5'b00000;
		cp0_reg_we_o    <= `WriteDisable;
		cp0_reg_data_o  <= `ZeroWord;
	end else if(aluop_i == `EXE_MTC0_OP) begin
        cp0_reg_waddr_o <= inst_i[15:11];
		cp0_reg_we_o    <= `WriteEnable;
		cp0_reg_data_o  <= reg1_i;
    end else begin
	    cp0_reg_waddr_o <= 5'b00000;
        cp0_reg_we_o    <= `WriteDisable;
        cp0_reg_data_o  <= `ZeroWord;
	end				
 end		

endmodule