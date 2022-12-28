module id (
    input                   rst,
    input [`InstAddrBus]    pc_i,
    input [`InstBus]        inst_i,

    // to solve load-relate 
    input [`AluOpBus]       ex_aluop_i,

    // read from regfile
    input [`RegBus]         reg1_data_i,
    input [`RegBus]         reg2_data_i,

    // read from excution phase to solve data hazard
    input                   ex_wreg_i,
    input [`RegBus]         ex_wdata_i,
    input [`RegAddrBus]     ex_wd_i,

    // read from mem phase to solve data hazard
    input                   mem_wreg_i,
    input [`RegBus]         mem_wdata_i,
    input [`RegAddrBus]     mem_wd_i,
    
    input                   is_in_delayslot_i,

    // send to regfile
    output reg              reg1_read_o,   // enable signal to regfile 
    output reg              reg2_read_o,
    output reg[`RegAddrBus] reg1_addr_o,
    output reg[`RegAddrBus] reg2_addr_o,

    // send to exe 
    output reg[`AluOpBus]   aluop_o,
    output reg[`AluSelBus]  alusel_o,
    output reg[`RegBus]     reg1_o,
    output reg[`RegBus]     reg2_o,
    output reg[`RegAddrBus] wd_o,
	output reg              wreg_o,
    output [`RegBus]        inst_o,      // send to exe for lw,sw,etc.

	output reg              next_inst_in_delayslot_o,
	
	output reg              branch_flag_o,
	output reg[`RegBus]     branch_addr_o,       
	output reg[`RegBus]     link_addr_o,
	output reg              is_in_delayslot_o,

    output [31:0]           excepttype_o,
    output [`RegBus]        cur_inst_addr_o,

	output wire             stallreq	
	
);


  wire[5:0] op    = inst_i[31:26];
  wire[4:0] rs    = inst_i[25:21];
  wire[4:0] rt    = inst_i[20:16];
  wire[4:0] rd    = inst_i[15:11];
  wire[4:0] shamt = inst_i[10:6];
  wire[5:0] funct = inst_i[5:0];
  wire[15:0] imm  = inst_i[15:0];
 
  wire[31:0] imm_zext; // imm zero-extend
  wire[31:0] imm_sext; // imm sign-extend
  wire[31:0] imm_jext; // J-fornat instruction extend 
  wire[31:0] imm_bext; // B-format instrction extend, signedExt 

  wire[`RegBus] pc_plus_4;
  wire[`RegBus] pc_plus_8; 
  
  assign pc_plus_4 = pc_i + 4;
  assign pc_plus_8 = pc_i + 8;

  assign imm_zext = {16'b0, imm};
  assign imm_sext = {{16{imm[15]}}, imm};
  assign imm_jext = {pc_plus_4[31:28], inst_i[25:0], 2'h0};
  assign imm_bext = {{14{imm[15]}}, imm, 2'h0} + pc_plus_4;

  reg[`RegBus]	imm_fnl;
  reg instvalid;

  reg  stallreq_for_reg1_loadrelate;
  reg  stallreq_for_reg2_loadrelate;
  wire pre_inst_is_load;

  reg excepttype_is_syscall;
  reg excepttype_is_eret;

  assign inst_o = inst_i;
  assign stallreq = stallreq_for_reg1_loadrelate | stallreq_for_reg2_loadrelate;
  assign pre_inst_is_load = ((ex_aluop_i == `EXE_LB_OP) || 
  							(ex_aluop_i == `EXE_LBU_OP)||
  							(ex_aluop_i == `EXE_LH_OP) ||
  							(ex_aluop_i == `EXE_LHU_OP)||
  							(ex_aluop_i == `EXE_LW_OP) ||
  							(ex_aluop_i == `EXE_LWR_OP)||
  							(ex_aluop_i == `EXE_LWL_OP)||
  							(ex_aluop_i == `EXE_LL_OP) ||
  							(ex_aluop_i == `EXE_SC_OP)) ? 1'b1 : 1'b0;

  //exceptiontype的低8bit留给外部中断，第9bit表示是否是syscall指令
  //第10bit表示是否是无效指令，第11bit表示是否是trap指令
  assign excepttype_o = {19'b0,excepttype_is_eret,2'b0,
  												instvalid, excepttype_is_syscall,8'b0};
  //assign excepttye_is_trapinst = 1'b0;
  
	assign cur_inst_addr_o = pc_i;

  // phase 1: instruction decode
  always @(*) begin
    if(rst == `RstEnable) begin
        aluop_o       <= `EXE_NOP_OP;
        alusel_o      <= `EXE_RES_NOP;
        wd_o          <= `NOPRegAddr;
        wreg_o        <= `WriteDisable;
        instvalid     <= `InstValid;
        reg1_read_o   <= `ReadDisable;
        reg2_read_o   <= `ReadDisable;
        reg1_addr_o   <= `NOPRegAddr;
        reg2_addr_o   <= `NOPRegAddr;
        imm_fnl       <= `ZeroWord;	
        link_addr_o   <= `ZeroWord;
        branch_addr_o <= `ZeroWord;
        branch_flag_o <= `NotBranch;
        next_inst_in_delayslot_o <= `NotInDelaySlot;	
		excepttype_is_syscall    <= `False_v;
		excepttype_is_eret       <= `False_v;	
    end else begin
        aluop_o       <= `EXE_NOP_OP;
        alusel_o      <= `EXE_RES_NOP;
        wd_o          <= rd;
        wreg_o        <= `WriteDisable;
        instvalid     <= `InstInvalid;
        reg1_read_o   <= `ReadDisable;
        reg2_read_o   <= `ReadDisable;
        reg1_addr_o   <= rs;
        reg2_addr_o   <= rt;
        imm_fnl       <= `ZeroWord;	  
        link_addr_o   <= `ZeroWord;
        branch_addr_o <= `ZeroWord;
        branch_flag_o <= `NotBranch;	
        next_inst_in_delayslot_o <= `NotInDelaySlot;
		excepttype_is_syscall    <= `False_v;
		excepttype_is_eret       <= `False_v;		

    case (op)
    `EXE_SPECIAL_INST: begin
        if (shamt == 5'b00000) begin
            case (funct)
		        `EXE_OR: begin
		            wreg_o      <= `WriteEnable;
		            aluop_o     <= `EXE_OR_OP;
		            alusel_o    <= `EXE_RES_LOGIC;
		            reg1_read_o <= `ReadEnable;
		            reg2_read_o <= `ReadEnable;
		            instvalid   <= `InstValid;
		        end
		        `EXE_AND: begin
		            wreg_o      <= `WriteEnable;
		            aluop_o     <= `EXE_AND_OP;
		            alusel_o    <= `EXE_RES_LOGIC;
		            reg1_read_o <= `ReadEnable;
		            reg2_read_o <= `ReadEnable;
		            instvalid   <= `InstValid;
		        end
		        `EXE_XOR: begin
		            wreg_o      <= `WriteEnable;
		            aluop_o     <= `EXE_XOR_OP;
		            alusel_o    <= `EXE_RES_LOGIC;
		            reg1_read_o <= `ReadEnable;
		            reg2_read_o <= `ReadEnable;
		            instvalid   <= `InstValid;
		        end
		        `EXE_NOR: begin
		            wreg_o      <= `WriteEnable;
		            aluop_o     <= `EXE_NOR_OP;
		            alusel_o    <= `EXE_RES_LOGIC;
		            reg1_read_o <= `ReadEnable;
		            reg2_read_o <= `ReadEnable;
		            instvalid   <= `InstValid;
                end
                `EXE_SLLV: begin
		            wreg_o      <= `WriteEnable;
		            aluop_o     <= `EXE_SLL_OP;
		            alusel_o    <= `EXE_RES_SHIFT;
		            reg1_read_o <= `ReadEnable;
		            reg2_read_o <= `ReadEnable;
		            instvalid   <= `InstValid;
                end
                `EXE_SRLV: begin
		            wreg_o      <= `WriteEnable;
		            aluop_o     <= `EXE_SRL_OP;
		            alusel_o    <= `EXE_RES_SHIFT;
		            reg1_read_o <= `ReadEnable;
		            reg2_read_o <= `ReadEnable;
		            instvalid   <= `InstValid;       
                end
                `EXE_SRAV: begin
		            wreg_o      <= `WriteEnable;
		            aluop_o     <= `EXE_SRA_OP;
		            alusel_o    <= `EXE_RES_SHIFT;
		            reg1_read_o <= `ReadEnable;
		            reg2_read_o <= `ReadEnable;
		            instvalid   <= `InstValid;         
                end
                // `EXE_SYNC: begin
		        //     wreg_o      <= `WriteDisable;
		        //     aluop_o     <= `EXE_NOP_OP;
		        //     alusel_o    <= `EXE_NOP_OP;
		        //     reg1_read_o <= `ReadDisable;
		        //     reg2_read_o <= `ReadDisable;
		        //     instvalid   <= `InstValid;      
                // end
                `EXE_MFHI: begin
		            wreg_o      <= `WriteEnable;
		            aluop_o     <= `EXE_MFHI_OP;
		            alusel_o    <= `EXE_RES_MOVE;
		            reg1_read_o <= `ReadDisable; // not reading from regfile but lohi reg
		            reg2_read_o <= `ReadEnable;
		            instvalid   <= `InstValid;   
                end
                `EXE_MFLO: begin
		            wreg_o      <= `WriteEnable;
		            aluop_o     <= `EXE_MFLO_OP;
		            alusel_o    <= `EXE_RES_MOVE;
		            reg1_read_o <= `ReadDisable; 
		            reg2_read_o <= `ReadEnable;
		            instvalid   <= `InstValid;   
                end
                `EXE_MTHI: begin
		            wreg_o      <= `WriteDisable;
		            aluop_o     <= `EXE_MTHI_OP;
		            reg1_read_o <= `ReadEnable; 
		            reg2_read_o <= `ReadDisable;
		            instvalid   <= `InstValid;   
                end
                `EXE_MTLO: begin
		            wreg_o      <= `WriteDisable;
		            aluop_o     <= `EXE_MTLO_OP;
		            reg1_read_o <= `ReadEnable; 
		            reg2_read_o <= `ReadDisable;
		            instvalid   <= `InstValid;   
                end
                `EXE_MOVN: begin
		            aluop_o     <= `EXE_MOVN_OP;
                    alusel_o    <= `EXE_RES_MOVE;
		            reg1_read_o <= `ReadEnable; 
		            reg2_read_o <= `ReadEnable;
		            instvalid   <= `InstValid;  
                    if (reg2_o != `ZeroWord) begin
                        wreg_o  <= `WriteEnable;
                    end else begin
                        wreg_o  <= `WriteDisable;
                    end
                end
                `EXE_MOVZ: begin
		            aluop_o     <= `EXE_MOVZ_OP;
                    alusel_o    <= `EXE_RES_MOVE;
		            reg1_read_o <= `ReadEnable; 
		            reg2_read_o <= `ReadEnable;
		            instvalid   <= `InstValid;  
                    if (reg2_o == `ZeroWord) begin
                        wreg_o  <= `WriteEnable;
                    end else begin
                        wreg_o  <= `WriteDisable;
                    end
                end
				`EXE_SLT: begin
				    wreg_o      <= `WriteEnable;	
                    aluop_o     <= `EXE_SLT_OP;
		  			alusel_o    <= `EXE_RES_ARITHMETIC;
                    reg1_read_o <= `ReadEnable;
                    reg2_read_o <= `ReadEnable;
		  			instvalid   <= `InstValid;	
				end
				`EXE_SLTU: begin
				    wreg_o      <= `WriteEnable;	
                    aluop_o     <= `EXE_SLTU_OP;
		  			alusel_o    <= `EXE_RES_ARITHMETIC;		
                    reg1_read_o <= `ReadEnable;	
                    reg2_read_o <= `ReadEnable;
					instvalid   <= `InstValid;	
				end
                `EXE_ADD: begin
                    wreg_o      <= `WriteEnable;
                    aluop_o     <= `EXE_ADD_OP;
                    alusel_o    <= `EXE_RES_ARITHMETIC;
                    reg1_read_o <= `ReadEnable;
                    reg2_read_o <= `ReadEnable;
                    instvalid   <= `InstValid;
                end
                `EXE_ADDU: begin
                    wreg_o      <= `WriteEnable;
                    aluop_o     <= `EXE_ADDU_OP;
                    alusel_o    <= `EXE_RES_ARITHMETIC;
                    reg1_read_o <= `ReadEnable;
                    reg2_read_o <= `ReadEnable;
                    instvalid   <= `InstValid;
                end
                `EXE_SUB: begin
                    wreg_o      <= `WriteEnable;
                    aluop_o     <= `EXE_SUB_OP;
                    alusel_o    <= `EXE_RES_ARITHMETIC;
                    reg1_read_o <= `ReadEnable;
                    reg2_read_o <= `ReadEnable;
                    instvalid   <= `InstValid;
                end
                `EXE_SUBU: begin
                    wreg_o      <= `WriteEnable;
                    aluop_o     <= `EXE_SUBU_OP;
                    alusel_o    <= `EXE_RES_ARITHMETIC;
                    reg1_read_o <= `ReadEnable;
                    reg2_read_o <= `ReadEnable;
                    instvalid   <= `InstValid;
                end
                `EXE_MULT: begin
                    wreg_o      <= `WriteDisable;
                    aluop_o     <= `EXE_MULT_OP;
                    reg1_read_o <= `ReadEnable;
                    reg2_read_o <= `ReadEnable;
                    instvalid   <= `InstValid;
                    // is_md = 1'b1;
                end
                `EXE_MULTU: begin
                    wreg_o      <= `WriteDisable;
                    aluop_o     <= `EXE_MULTU_OP;
                    reg1_read_o <= `ReadEnable;
                    reg2_read_o <= `ReadEnable;
                    instvalid   <= `InstValid;
                    // is_md = 1'b1;
                end
                `EXE_DIV: begin
                    wreg_o      <= `WriteDisable;     // write to holi
                    aluop_o     <= `EXE_DIV_OP;
                    reg1_read_o <= `ReadEnable;
                    reg2_read_o <= `ReadEnable;
                    instvalid   <= `InstValid;
                end
                `EXE_DIVU: begin
                    wreg_o      <= `WriteDisable;
                    aluop_o     <= `EXE_DIV_OP;
                    reg1_read_o <= `ReadEnable;
                    reg2_read_o <= `ReadEnable;
                    instvalid   <= `InstValid;   
                end
                `EXE_JR: begin
                    wreg_o        <= `WriteDisable;
                    aluop_o       <= `EXE_JR_OP;
                    alusel_o      <= `EXE_RES_JUMP_BRANCH;
                    reg1_read_o   <= `ReadEnable;
                    reg2_read_o   <= `ReadDisable;
                    link_addr_o   <= `ZeroWord;
                    branch_addr_o <= reg1_o;
                    branch_flag_o <= `DoBranch;
                    instvalid     <= `InstValid;
                    next_inst_in_delayslot_o <= `InDelaySlot;
                    // is_jb = 1'b1;
                end
                `EXE_JALR: begin
                    wreg_o        <= `WriteEnable;
                    aluop_o       <= `EXE_JALR_OP;
                    alusel_o      <= `EXE_RES_JUMP_BRANCH;
                    reg1_read_o   <= `ReadEnable;
                    reg2_read_o   <= `ReadDisable;
                    link_addr_o   <= pc_plus_8;
                    branch_addr_o <= reg1_o;
                    branch_flag_o <= `DoBranch;
                    instvalid     <= `InstValid;
                    next_inst_in_delayslot_o <= `InDelaySlot;
                    // is_jb = 1'b1;
                end
            endcase // endcase funct
        end // end if (shamt)
        case (funct)
            `EXE_TEQ: begin
                wreg_o      <= `WriteDisable;
                aluop_o     <= `EXE_TEQ_OP;
                alusel_o    <= `EXE_RES_NOP;
                reg1_read_o <= `ReadEnable;
                reg2_read_o <= `ReadEnable;
                instvalid   <= `InstValid;
                // is_cp0 = 1'b1;
            end
            `EXE_TGE: begin
                wreg_o      <= `WriteDisable;
                aluop_o     <= `EXE_TGE_OP;
                alusel_o    <= `EXE_RES_NOP;
                reg1_read_o <= `ReadEnable;
                reg2_read_o <= `ReadEnable;
                instvalid   <= `InstValid;
                // is_cp0 = 1'b1;
            end
            `EXE_TGEU: begin
                wreg_o      <= `WriteDisable;
                aluop_o     <= `EXE_TGEU_OP;
                alusel_o    <= `EXE_RES_NOP;
                reg1_read_o <= `ReadEnable;
                reg2_read_o <= `ReadEnable;
                instvalid   <= `InstValid;
                // is_cp0 = 1'b1;
            end
            `EXE_TLT: begin
                wreg_o      <= `WriteDisable;
                aluop_o     <= `EXE_TLT_OP;
                alusel_o    <= `EXE_RES_NOP;
                reg1_read_o <= `ReadEnable;
                reg2_read_o <= `ReadEnable;
                instvalid   <= `InstValid;
                // is_cp0 = 1'b1;
            end
            `EXE_TLTU: begin
                wreg_o      <= `WriteDisable;
                aluop_o     <= `EXE_TLTU_OP;
                alusel_o    <= `EXE_RES_NOP;
                reg1_read_o <= `ReadEnable;
                reg2_read_o <= `ReadEnable;
                instvalid   <= `InstValid;
                // is_cp0 = 1'b1;
            end
            `EXE_TNE: begin
                wreg_o      <= `WriteDisable;
                aluop_o     <= `EXE_TNE_OP;
                alusel_o    <= `EXE_RES_NOP;
                reg1_read_o <= `ReadEnable;
                reg2_read_o <= `ReadEnable;
                instvalid   <= `InstValid;
                // is_cp0 = 1'b1;
            end
            `EXE_SYSCALL: begin
                wreg_o      <= `WriteDisable;
                aluop_o     <= `EXE_SYSCALL_OP;
                alusel_o    <= `EXE_RES_NOP;
                reg1_read_o <= `ReadDisable;
                reg2_read_o <= `ReadDisable;
                instvalid   <= `InstValid;
                excepttype_is_syscall <= 1'b1;
                // is_cp0 = 1'b1;
            end
            default: ;
        endcase
    end
    `EXE_ORI: begin
        wreg_o      <= `WriteEnable;
        aluop_o     <= `EXE_OR_OP;
        alusel_o    <= `EXE_RES_LOGIC;
        reg1_read_o <= `ReadEnable;
        reg2_read_o <= `ReadDisable;
        imm_fnl     <= imm_zext;
        wd_o        <= rt; 
        instvalid   <= `InstValid; 
    end
    `EXE_ANDI: begin
        wreg_o      <= `WriteEnable;
        aluop_o     <= `EXE_AND_OP;
        alusel_o    <= `EXE_RES_LOGIC;
        reg1_read_o <= `ReadEnable;
        reg2_read_o <= `ReadDisable;
        imm_fnl     <= imm_zext;
        wd_o        <= rt;
        instvalid   <= `InstValid;
    end
    `EXE_XORI: begin
        wreg_o      <= `WriteEnable;
        aluop_o     <= `EXE_XOR_OP;
        alusel_o    <= `EXE_RES_LOGIC;
        reg1_read_o <= `ReadEnable;
        reg2_read_o <= `ReadDisable;	  	
        imm_fnl     <= imm_zext;
        wd_o        <= rt;
        instvalid   <= `InstValid;
    end
    `EXE_LUI: begin
        wreg_o      <= `WriteEnable;
        aluop_o     <= `EXE_OR_OP;
        alusel_o    <= `EXE_RES_LOGIC;
        reg1_read_o <= `ReadEnable;
        reg2_read_o <= `ReadDisable;	  	
        imm_fnl     <= {imm, 16'h0};
        wd_o        <= rt;
        instvalid   <= `InstValid;
    end
    `EXE_SLTI: begin
        aluop_o     <= `EXE_SLT_OP;
        alusel_o    <= `EXE_RES_ARITHMETIC;
        wd_o        <= rt;
        wreg_o      <= `WriteEnable;
        instvalid   <= `InstValid;
        reg1_read_o <= `ReadEnable;
        reg2_read_o <= `ReadDisable;
        imm_fnl     <= imm_sext;
    end
    `EXE_SLTIU: begin
        aluop_o     <= `EXE_SLTU_OP;
        alusel_o    <= `EXE_RES_ARITHMETIC;
        wd_o        <= rt;
        wreg_o      <= `WriteEnable;
        instvalid   <= `InstValid;
        reg1_read_o <= `ReadEnable;
        reg2_read_o <= `ReadDisable;
        imm_fnl     <= imm_sext;
    end
    `EXE_ADDI: begin
        aluop_o     <= `EXE_ADDI_OP;
        alusel_o    <= `EXE_RES_ARITHMETIC;
        wd_o        <= rt;
        wreg_o      <= `WriteEnable;
        instvalid   <= `InstValid;
        reg1_read_o <= `ReadEnable;
        reg2_read_o <= `ReadDisable;
        imm_fnl     <= imm_sext;
    end
    `EXE_ADDIU: begin
        aluop_o     <= `EXE_ADDIU_OP;
        alusel_o    <= `EXE_RES_ARITHMETIC;
        wd_o        <= rt;
        wreg_o      <= `WriteEnable;
        instvalid   <= `InstValid;
        reg1_read_o <= `ReadEnable;
        reg2_read_o <= `ReadDisable;
        imm_fnl     <= imm_sext;
    end
    `EXE_J: begin
        aluop_o       <= `EXE_J_OP;
        alusel_o      <= `EXE_RES_JUMP_BRANCH;
        wreg_o        <= `WriteDisable;
        instvalid     <= `InstValid;
        reg1_read_o   <= `ReadDisable;
        reg2_read_o   <= `ReadDisable;
        link_addr_o   <=`ZeroWord;
        branch_flag_o <= `DoBranch;
        branch_addr_o <= imm_jext;
        next_inst_in_delayslot_o <= `InDelaySlot;
        // is_jb = 1'b1;
    end
    `EXE_JAL: begin
        aluop_o       <= `EXE_JAL_OP;
        alusel_o      <= `EXE_RES_JUMP_BRANCH;
        wd_o          <= 5'b11111;
        wreg_o        <= `WriteEnable;
        instvalid     <= `InstValid;
        reg1_read_o   <= `ReadDisable;
        reg2_read_o   <= `ReadDisable;
        link_addr_o   <= pc_plus_8;
        branch_flag_o <= `DoBranch;
        branch_addr_o <= imm_jext;
        next_inst_in_delayslot_o = `InDelaySlot;
        // is_jb = 1'b1;
    end
    `EXE_BEQ: begin
        aluop_o       <= `EXE_BEQ_OP;
        alusel_o      <= `EXE_RES_JUMP_BRANCH;
        wreg_o        <= `WriteDisable;
        instvalid     <= `InstValid;
        reg1_read_o   <= `ReadEnable;
        reg2_read_o   <= `ReadEnable;
        if (reg1_o == reg2_o) begin
            branch_addr_o <= imm_bext;
            branch_flag_o <= `DoBranch;
            next_inst_in_delayslot_o <= `InDelaySlot;
        end
        // is_jb = 1'b1;
    end
    `EXE_LB: begin
        aluop_o         <= `EXE_LB_OP;
        alusel_o        <= `EXE_RES_LOAD_STORE;
        wd_o            <= rt;
        wreg_o          <= `WriteEnable;
        instvalid       <= `InstValid;
        reg1_read_o     <= `ReadEnable;
        reg2_read_o     <= `ReadDisable;
        // is_ls = 1'b1;
    end
    `EXE_LW: begin
        wreg_o          <= `WriteEnable;	
        aluop_o         <= `EXE_LW_OP;
        alusel_o        <= `EXE_RES_LOAD_STORE;
        reg1_read_o     <= `ReadEnable;
        reg2_read_o     <= `ReadDisable;
        wd_o            <= rt; 
        instvalid       <= `InstValid;	
	end
    `EXE_SB: begin
        aluop_o         <= `EXE_SB_OP;
        alusel_o        <= `EXE_RES_LOAD_STORE;
        wreg_o          <= `WriteDisable;
        instvalid       <= `InstValid;
        reg1_read_o     <= `ReadEnable;
        reg2_read_o     <= `ReadEnable;
        // is_ls = 1'b1;
    end
    `EXE_SH: begin
        aluop_o         <= `EXE_SH_OP;
        alusel_o        <= `EXE_RES_LOAD_STORE;
        wreg_o          <= `WriteDisable;
        instvalid       <= `InstValid;
        reg1_read_o     <= `ReadEnable;
        reg2_read_o     <= `ReadEnable;
        // is_ls = 1'b1;
    end
    `EXE_SW: begin
        aluop_o         <= `EXE_SW_OP;
        alusel_o        <= `EXE_RES_LOAD_STORE;
        wreg_o          <= `WriteDisable;
        instvalid       <= `InstValid;
        reg1_read_o     <= `ReadEnable;
        reg2_read_o     <= `ReadEnable;
        // is_ls = 1'b1;
    end
    `EXE_LL: begin
        aluop_o         <= `EXE_LL_OP;
        alusel_o        <= `EXE_RES_LOAD_STORE;
        wreg_o          <= `WriteEnable;
        instvalid       <= `InstValid;
        reg1_read_o     <= `ReadEnable;
        reg2_read_o     <= `ReadDisable;  
        wd_o            <= rt;
    end
    `EXE_SC: begin
        aluop_o         <= `EXE_SC_OP;
        alusel_o        <= `EXE_RES_LOAD_STORE;
        wreg_o          <= `WriteEnable;
        instvalid       <= `InstValid;
        reg1_read_o     <= `ReadEnable;
        reg2_read_o     <= `ReadEnable;  
        wd_o            <= rt;
    end
    `EXE_COP0: begin
        if(inst_i[25:21] == 5'b00000 && inst_i[10:3] == 8'b00000000) begin
            aluop_o     <= `EXE_MFC0_OP;
            alusel_o    <= `EXE_RES_MOVE;
            wd_o        <= rt;
            wreg_o      <= `WriteEnable;
			instvalid   <= `InstValid;
            reg1_read_o <= `ReadDisable;
            reg2_read_o <= `ReadDisable;
		end else if(inst_i[25:21] == 5'b00100 && inst_i[10:3] == 8'b00000000) begin
            aluop_o     <= `EXE_MTC0_OP;
            alusel_o    <= `EXE_RES_NOP;
            wreg_o      <= `WriteDisable;
            instvalid   <= `InstValid;	   
            reg1_read_o <= `ReadEnable;
            reg2_read_o <= `ReadDisable;
            reg1_addr_o <= rt;
        end
    end
	`EXE_REGIMM_INST: begin
        case (rt)
            `EXE_BGEZ:	begin
			    wreg_o <= `WriteDisable;		
                aluop_o <= `EXE_BGEZ_OP;
		  		alusel_o <= `EXE_RES_JUMP_BRANCH; 
                reg1_read_o <= `ReadEnable;	
                reg2_read_o <= `ReadDisable;
		  		instvalid <= `InstValid;	
		  		if(reg1_o[31] == 1'b0) begin
			        branch_addr_o <= imm_bext;
			    	branch_flag_o <= `DoBranch;
			    	next_inst_in_delayslot_o <= `InDelaySlot;		  	
		    	end
            end
			`EXE_BGEZAL: begin
                wreg_o <= `WriteEnable;		
                aluop_o <= `EXE_BGEZAL_OP;
		  		alusel_o <= `EXE_RES_JUMP_BRANCH; 
                reg1_read_o <= `ReadEnable;	
                reg2_read_o <= `ReadDisable;
		  		link_addr_o <= pc_plus_8; 
		  		wd_o <= 5'b11111;  	
                instvalid <= `InstValid;
		  		if(reg1_o[31] == 1'b0) begin
			        branch_addr_o <= imm_bext;
			    	branch_flag_o <= `DoBranch;
			    	next_inst_in_delayslot_o <= `InDelaySlot;
				end
			end
			`EXE_BLTZ: begin
				wreg_o <= `WriteDisable;		
                aluop_o <= `EXE_BGEZAL_OP;
		  		alusel_o <= `EXE_RES_JUMP_BRANCH; 
                reg1_read_o <= `ReadEnable;	
                reg2_read_o <= `ReadDisable;
		  		instvalid <= `InstValid;	
		  		if(reg1_o[31] == 1'b1) begin
			        branch_addr_o <= imm_bext;
			    	branch_flag_o <= `DoBranch;
			    	next_inst_in_delayslot_o <= `InDelaySlot;		  	
				end
			end
			`EXE_BLTZAL: begin
			    wreg_o <= `WriteEnable;		
                aluop_o <= `EXE_BGEZAL_OP;
		  	    alusel_o <= `EXE_RES_JUMP_BRANCH; 
                reg1_read_o <= `ReadEnable;	
                reg2_read_o <= `ReadDisable;
		  		link_addr_o <= pc_plus_8;	
		  		wd_o <= 5'b11111; 
                instvalid <= `InstValid;
		  		if(reg1_o[31] == 1'b1) begin
			        branch_addr_o <= imm_bext;
			    	branch_flag_o <= `DoBranch;
			    	next_inst_in_delayslot_o <= `InDelaySlot;
			    end
		    end
			`EXE_TEQI: begin
		  	    wreg_o      <= `WriteDisable;		
                aluop_o     <= `EXE_TEQI_OP;
		  		alusel_o    <= `EXE_RES_NOP; 
                reg1_read_o <= `ReadEnable;	
                reg2_read_o <= `ReadDisable;	  	
				imm_fnl     <= {{16{inst_i[15]}}, inst_i[15:0]};		  	
				instvalid   <= `InstValid;	
			end
			`EXE_TGEI: begin
		  	    wreg_o      <= `WriteDisable;		
                aluop_o     <= `EXE_TGEI_OP;
		  		alusel_o    <= `EXE_RES_NOP; 
                reg1_read_o <= `ReadEnable;	
                reg2_read_o <= `ReadDisable;  	
				imm_fnl     <= {{16{inst_i[15]}}, inst_i[15:0]};		  	
				instvalid   <= `InstValid;	
			end
			`EXE_TGEIU: begin
		  	    wreg_o      <= `WriteDisable;		
                aluop_o     <= `EXE_TGEIU_OP;
		  		alusel_o    <= `EXE_RES_NOP; 
                reg1_read_o <= `ReadEnable;	
                reg2_read_o <= `ReadDisable;	  	
				imm_fnl     <= {{16{inst_i[15]}}, inst_i[15:0]};		  	
				instvalid   <= `InstValid;	
			end
	        `EXE_TLTI: begin
		  	    wreg_o      <= `WriteDisable;		
                aluop_o     <= `EXE_TLTI_OP;
		  	    alusel_o    <= `EXE_RES_NOP; 
                reg1_read_o <= 1'b1;	
                reg2_read_o <= 1'b0;	  	
			    imm_fnl     <= {{16{inst_i[15]}}, inst_i[15:0]};		  	
			    instvalid   <= `InstValid;	
			end
			`EXE_TLTIU: begin
		  	    wreg_o      <= `WriteDisable;		
                aluop_o     <= `EXE_TLTIU_OP;
		  		alusel_o    <= `EXE_RES_NOP; 
                reg1_read_o <= `ReadEnable;	
                reg2_read_o <= `ReadDisable;	  	
				imm_fnl     <= {{16{inst_i[15]}}, inst_i[15:0]};		  	
				instvalid   <= `InstValid;	
			end
			`EXE_TNEI: begin
		  	    wreg_o      <= `WriteDisable;		
                aluop_o     <= `EXE_TNEI_OP;
		  		alusel_o    <= `EXE_RES_NOP; 
                reg1_read_o <= `ReadEnable;	
                reg2_read_o <= `ReadDisable;
				imm_fnl     <= {{16{inst_i[15]}}, inst_i[15:0]};		  	
				instvalid   <= `InstValid;	
			end						
		    default: ;
		endcase
	end		
    `EXE_SPECIAL2_INST: begin
        case (funct)
            `EXE_MUL: begin
                wreg_o      <= `WriteEnable;
                aluop_o     <= `EXE_MUL_OP;
                alusel_o    <= `EXE_RES_MUL;
                reg1_read_o <= `ReadEnable;
                reg2_read_o <= `ReadEnable;
                instvalid   <= `InstValid;
            end
        endcase
    end
    endcase 

    // endcase opcode

    if (inst_i[31:21] == 11'b00000000000) begin
        case (funct)
        `EXE_SLL: begin
            wreg_o      <= `WriteEnable;
            aluop_o     <= `EXE_SLL_OP;
            alusel_o    <= `EXE_RES_SHIFT;
            reg1_read_o <= `ReadDisable;
            reg2_read_o <= `ReadEnable;	  	
            imm_fnl     <= shamt;
            wd_o        <= rd;
            instvalid   <= `InstValid;
        end
        `EXE_SRL: begin
            wreg_o      <= `WriteEnable;
            aluop_o     <= `EXE_SRL_OP;
            alusel_o    <= `EXE_RES_SHIFT;
            reg1_read_o <= `ReadDisable;
            reg2_read_o <= `ReadEnable;	  	
            imm_fnl     <= shamt;
            wd_o        <= rd;
            instvalid   <= `InstValid;
        end
        `EXE_SRA: begin
            wreg_o      <= `WriteEnable;
            aluop_o     <= `EXE_SRA_OP;
            alusel_o    <= `EXE_RES_SHIFT;
            reg1_read_o <= `ReadDisable;
            reg2_read_o <= `ReadEnable;	  	
            imm_fnl     <= shamt;
            wd_o        <= rd;
            instvalid   <= `InstValid;
        end
        endcase
    end
    if(inst_i == `EXE_ERET) begin
	    wreg_o             <= `WriteDisable;		
        aluop_o            <= `EXE_ERET_OP;
		alusel_o           <= `EXE_RES_NOP;   
        reg1_read_o        <= `ReadDisable;	
        reg2_read_o        <= `ReadDisable;
		instvalid          <= `InstValid; 
        excepttype_is_eret <= `True_v;				
	end else if(inst_i[31:21] == 11'b01000000000 && 
                inst_i[10: 0] == 11'b00000000000) begin
		aluop_o     <= `EXE_MFC0_OP;
		alusel_o    <= `EXE_RES_MOVE;
		wd_o        <= inst_i[20:16];
		wreg_o      <= `WriteEnable;
		instvalid   <= `InstValid;	   
		reg1_read_o <= `ReadDisable;
		reg2_read_o <= `ReadDisable;		
	end else if(inst_i[31:21] == 11'b01000000100 && 
                inst_i[10: 0] == 11'b00000000000) begin
		aluop_o     <= `EXE_MTC0_OP;
		alusel_o    <= `EXE_RES_NOP;
		wreg_o      <= `WriteDisable;
		instvalid   <= `InstValid;	   
		reg1_read_o <= `ReadEnable;
	    reg1_addr_o <= inst_i[20:16];
		reg2_read_o <= `ReadDisable;				
	end


    end


  end // end always



  // phase 2: determine operation num_1
  always @ (*) begin
    stallreq_for_reg1_loadrelate <= `NoStop;
    if(rst == `RstEnable) begin
        reg1_o <= `ZeroWord;
    /* data bypass */ 
    end else if(pre_inst_is_load == 1'b1 && ex_wd_i == reg1_addr_o 
	            && reg1_read_o == 1'b1 ) begin
        stallreq_for_reg1_loadrelate <= `Stop;
    end else if ( (reg1_read_o == `ReadEnable) && (ex_wreg_i == `WriteEnable)
               && (ex_wd_i == reg1_addr_o) ) begin
        reg1_o <= ex_wdata_i; 
    end else if ( (reg1_read_o == `ReadEnable) && (mem_wreg_i == `WriteEnable)
               && (mem_wd_i == reg1_addr_o) ) begin
        reg1_o <= mem_wdata_i; 
    end else if(reg1_read_o == `ReadEnable) begin
        reg1_o <= reg1_data_i;
    end else if(reg1_read_o == `ReadDisable) begin 
        reg1_o <= imm_fnl;
    end else begin
        reg1_o <= `ZeroWord;
    end
  end

  // phase 3: determine operation num_2
  always @ (*) begin
	stallreq_for_reg2_loadrelate <= `NoStop;
    if(rst == `RstEnable) begin
        reg2_o <= `ZeroWord;
    end else if(pre_inst_is_load == 1'b1 && ex_wd_i == reg2_addr_o 
                && reg2_read_o == 1'b1 ) begin
	    stallreq_for_reg2_loadrelate <= `Stop;
    /* data bypass */ 
    end else if ( (reg2_read_o == `ReadEnable) && (ex_wreg_i == `WriteEnable)
               && (ex_wd_i == reg2_addr_o) ) begin
        reg2_o <= ex_wdata_i; 
    end else if ( (reg2_read_o == `ReadEnable) && (mem_wreg_i == `WriteEnable)
               && (mem_wd_i == reg2_addr_o) ) begin
        reg2_o <= mem_wdata_i; 
    end else if(reg2_read_o == `ReadEnable) begin
        reg2_o <= reg2_data_i;
    end else if(reg2_read_o == `ReadDisable) begin 
        reg2_o <= imm_fnl;
    end else begin
        reg2_o <= `ZeroWord;
    end
  end


  always @ (*) begin
	if(rst == `RstEnable) begin
		is_in_delayslot_o <= `NotInDelaySlot;
	end else begin
        is_in_delayslot_o <= is_in_delayslot_i;		
	end
  end
  
//   always@(*) begin
//     if(is_in_delayslot_i == 1'b1) begin
//         aluop_o       <= `EXE_NOP_OP;
//         alusel_o      <= `EXE_RES_NOP;
//         wd_o          <= `NOPRegAddr;
//         wreg_o        <= `WriteDisable;
//         instvalid     <= `InstValid;
//         reg1_read_o   <= `ReadDisable;
//         reg2_read_o   <= `ReadDisable;
//         reg1_addr_o   <= `NOPRegAddr;
//         reg2_addr_o   <= `NOPRegAddr;
//         imm_fnl       <= `ZeroWord;
//         link_addr_o   <= `ZeroWord;
//         branch_addr_o <= `ZeroWord;
//         branch_flag_o <= `NotBranch;
//         next_inst_in_delayslot_o <= `NotInDelaySlot;	 
//     end
//   end

endmodule