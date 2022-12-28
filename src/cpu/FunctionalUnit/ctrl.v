// ctrl whether pasuse the pipeline
module ctrl (
    input               rst,
    input               stallreq_from_id,
    input               stallreq_from_ex,

    input [31:0]        excepttype_i,
    input [`RegBus]     cp0_epc_i,


    output reg[`RegBus] new_pc,
    output reg          flush,           

    // stall[0] = 1'b1: pc stay still
    // stall[1] = 1'b1: if pause
    // stall[2] = 1'b1: id pause
    // stall[3] = 1'b1: ex pause
    // stall[4] = 1'b1: mem pause
    // stall[5] = 1'b1: wb pause
    output reg[5:0]     stall
);

always @(*) begin
    if(rst == `RstEnable) begin
        stall  <= 6'b000000;
        flush  <= `NoFlush;
        new_pc <= `ZeroWord;
    end else if(excepttype_i != `ZeroWord) begin
        flush  <= `Flush;
        stall  <= 6'b000000;
		case (excepttype_i)
		    32'h00000001: new_pc <= 32'h00000020;  //interrupt
			32'h00000008: new_pc <= 32'h00000040;  //syscal 
			32'h0000000a: new_pc <= 32'h00000040;  //inst_invalid
			32'h0000000d: new_pc <= 32'h00000040;  //trap
		    32'h0000000c: new_pc <= 32'h00000040;  //ov
		    32'h0000000e: new_pc <= cp0_epc_i;     //eret
		    default: ;
		endcase 
    end else if(stallreq_from_ex == `Stop) begin
        stall  <= 6'b001111;
        flush  <= `NoFlush;
    end else if(stallreq_from_id == `Stop) begin
        stall  <= 6'b000111;
        flush  <= `NoFlush;
    end else begin
        stall  <= 6'b000000;
        flush  <= `NoFlush;
        new_pc <= `ZeroWord;
    end
end
    
endmodule