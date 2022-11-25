`include "defines.v"

// ctrl whether pasuse the pipeline
module ctrl (
    input           rst,
    input           stallreq_from_id,
    input           stallreq_from_ex,

    // stall[0] = 1'b1: pc stay still
    // stall[1] = 1'b1: if pause
    // stall[2] = 1'b1: id pause
    // stall[3] = 1'b1: ex pause
    // stall[4] = 1'b1: mem pause
    // stall[5] = 1'b1: wb pause
    output reg[5:0] stall
);

always @(*) begin
    if(rst == `RstEnable) begin
        stall <= 6'b000000;
    end else if(stallreq_from_ex == `Stop) begin
        stall <= 6'b001111;
    end else if(stallreq_from_id == `Stop) begin
        stall <= 6'b000111;
    end else begin
        stall <= 6'b000000;
    end
end
    
endmodule