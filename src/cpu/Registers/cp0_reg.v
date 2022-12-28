module cp0_reg(
    input                        clk,
    input                        rst,

    input                        we_i,
    input [4: 0]                 waddr_i,             
    input [4: 0]                 raddr_i,
    input [`RegBus]              data_i,

    input [5: 0]                 interrupt_i,

    input [31:0]                 excepttype_i,
    input [`RegBus]              cur_inst_addr_i,
    input                        is_in_delayslot_i,                  

    output reg[`RegBus]          data_o,
    output reg[`RegBus]          count_o,
    output reg[`RegBus]          compare_o,
    output reg[`RegBus]          status_o,
    output reg[`RegBus]          cause_o,
    output reg[`RegBus]          epc_o,
    output reg[`RegBus]          config_o,
    output reg[`RegBus]          PRId_o,        // Processor Identifier

    output reg                   timer_interrupt_o
);

  always @(posedge clk or posedge rst) begin
    if(rst == `RstEnable) begin
        count_o              <= `ZeroWord;
        compare_o            <= `ZeroWord;
        status_o             <= 32'h10000000;    // CP0 exsit
        cause_o              <= `ZeroWord;
        epc_o                <= `ZeroWord;
        config_o             <= 32'h00008000;
        PRId_o               <= 32'h004c0102;   // !! TODO
        timer_interrupt_o    <= `InterruptNotAssert;
    end else begin
        count_o        <= count_o + 1;
        cause_o[15:10] <= interrupt_i;

        if(compare_o != `ZeroWord && count_o == compare_o) begin
            timer_interrupt_o <= `InterruptAssert;
        end

        if(we_i == `WriteEnable) begin
            case (waddr_i)
                `CP0_REG_COUNT:     count_o  <= data_i;
                `CP0_REG_STATUS:    status_o <= data_i;
                `CP0_REG_EPC :      epc_o    <= data_i;
                `CP0_REG_COMPARE: begin
                    compare_o                <= data_i;
                    timer_interrupt_o        <= `InterruptNotAssert;    
                end  
                `CP0_REG_CAUSE: begin
                  cause_o[9:8] <= data_i[9:8];
                  cause_o[23]  <= data_i[23];
                  cause_o[22]  <= data_i[22];
                end
            endcase
            $display("CP0:$%d<=%h", waddr_i, data_i);
        end

        case(excepttype_i)
			32'h00000001: begin       //外部中断
    		    if(is_in_delayslot_i == `InDelaySlot ) begin
				    epc_o       <= cur_inst_addr_i - 4 ;
					cause_o[31] <= 1'b1;
			    end else begin
                    epc_o       <= cur_inst_addr_i;
                    cause_o[31] <= 1'b0;
                end
                status_o[1]     <= 1'b1;
                cause_o[6:2]    <= 5'b00000;
            end
            32'h00000008:	begin       // syscall
				if(status_o[1] == 1'b0) begin
				    if(is_in_delayslot_i == `InDelaySlot ) begin
					    epc_o       <= cur_inst_addr_i - 4 ;
						cause_o[31] <= 1'b1;
					end else begin
                        epc_o       <= cur_inst_addr_i;
                        cause_o[31] <= 1'b0;
					end
				end
                status_o[1]  <= 1'b1;
                cause_o[6:2] <= 5'b01000;			
			end
			32'h0000000a:	begin         // invalid inst
			    if(status_o[1] == 1'b0) begin
				    if(is_in_delayslot_i == `InDelaySlot ) begin
					    epc_o       <= cur_inst_addr_i - 4 ;
						cause_o[31] <= 1'b1;
					end else begin
                        epc_o       <= cur_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end
				end
                status_o[1]  <= 1'b1;
                cause_o[6:2] <= 5'b01010;					
			end
			32'h0000000d: begin           // trap
                if(status_o[1] == 1'b0) begin
                    if(is_in_delayslot_i == `InDelaySlot ) begin
                        epc_o       <= cur_inst_addr_i - 4 ;
                        cause_o[31] <= 1'b1;
                    end else begin
                        epc_o       <= cur_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end
                end
                status_o[1]  <= 1'b1;
                cause_o[6:2] <= 5'b01101;					
            end
            32'h0000000c:	begin         // overflow
                if(status_o[1] == 1'b0) begin
                    if(is_in_delayslot_i == `InDelaySlot ) begin
                        epc_o       <= cur_inst_addr_i - 4 ;
                        cause_o[31] <= 1'b1;
                    end else begin
                        epc_o       <= cur_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end
                end
                status_o[1]  <= 1'b1;
                cause_o[6:2] <= 5'b01100;					
            end				
            32'h0000000e:   begin    // eret
                status_o[1] <= 1'b0;
            end
            default: begin
            end
        endcase
    end
  end


  always @ (*) begin
    if(rst == `RstEnable) begin
      data_o <= `ZeroWord;
		end else begin
			case (raddr_i) 
				`CP0_REG_COUNT:      data_o <= count_o;
				`CP0_REG_COMPARE:	 data_o <= compare_o;
				`CP0_REG_STATUS:	 data_o <= status_o;
				`CP0_REG_CAUSE:	     data_o <= cause_o;
				`CP0_REG_EPC:	     data_o <= epc_o ;
				`CP0_REG_PRId:	     data_o <= PRId_o ;
				`CP0_REG_CONFIG:	 data_o <= config_o ;				
				default: 	begin end			
			endcase  //case addr_i			
		end   
  end     

endmodule