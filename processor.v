`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/06/2017 02:04:30 PM
// Design Name: 
// Module Name: processor
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`define word		[15:0]
`define opcode      [15:12]
`define opcodeSystemLen [4:0]
`define dest        [11:8]
`define src         [7:4]
`define Tsrc        [3:0]
`define	I	        [7:0]	// Immediate
`define regName     [3:0]
`define regsize		[15:0]
`define memsize 	[65535:0]
`define width		16;

//condition codes
`define fPos [0]
`define ltPos [1]
`define lePos [2]
`define eqPos [3]
`define nePos [4]
`define gePos [5]
`define gtPos [6]
`define tPos [7]

//op codes
`define OPad	4'b0000
`define OPan	4'b0001
`define OPor	4'b0010
`define OPno	4'b0011
`define OPeo	4'b0100
`define OPmi	4'b0101
`define OPal	4'b0110
`define OPdl	4'b0111
`define OPml	4'b1000
`define OPsr	4'b1001
`define OPbr	4'b1010
`define OPjr	4'b1011
`define OPli	4'b1100
`define OPsi	4'b1101
`define OPlo	4'b1110
`define OPcl	4'b1110
`define OPco	4'b1110
`define OPst	4'b1110
`define OPnl	4'b1110
`define OPsy	4'b1111

`define OPnop   5'b11111

module decode(opout, regdst, opin, ir);
    output reg `opcodeSystemLen opout;
    output reg `regName regdst;
    input wire `opcodeSystemLen opin;
    input `word ir;
    
    always@(opin, ir) begin
        case(ir`opcode)
//                `OPor: opout = `OPor;
//                `OPst: opout = `OPst;
            `OPco: 
                begin
                    case(ir `dest) //use dest as extended opcode
                        //cl
                        //4'b0000: opout = `OPcl; //not needed for this assignment
                        //co
                        4'b0001: begin opout = `OPco; regdst = 0; end
                        default:
                            case(ir `Tsrc) //use t src as extended opcode
                                //lo
                                4'b0010: begin opout = `OPlo; regdst <= ir `dest; end
                                //nl
                                //4'b0011: opout = `OPnl; //dont need to implement for this assignment
                                //st
                                4'b0100: begin opout = `OPst; regdst <= 0; end
                                default: begin opout = `OPnop; regdst <= 0; end //call a system stop because we shouldnt be here
                            endcase
                    endcase
                end
//                `OPno: opout = `OPno;
//                `OPmi: opout = `OPmi;
                `OPjr: begin opout = `OPjr; regdst <= 0; end
                `OPbr: begin opout = `OPbr; regdst <= 0; end
                `OPsy: begin opout = ir`opcode; regdst <= 0; end
            default: begin opout = ir `opcode; regdst <= ir `dest; end    // most instructions, state # is opcode
        endcase
    end
endmodule

module ALU(ALUResult, cond, instruct, currentTsrc, currentDst, a, b);
    
    output reg `word ALUResult;
    input wire `opcodeSystemLen instruct;
    input wire `word a, b;
    input wire `regName currentDst, currentTsrc;
    
    output reg [7:0] cond;
    initial cond = 8'b10000000; //t gt ge ne eq le lt f

    
    always@(instruct, a, b, currentTsrc, currentDst) begin
        case(instruct)
            `OPad:
                begin
                    ALUResult = a+b;
                end
            `OPan: ALUResult = a&b;
            `OPeo: ALUResult = a^b;
            `OPmi: ALUResult = (~a)+1; //2's complement??
            `OPno: ALUResult = !a;
            `OPor: ALUResult = a|b;
            `OPsr: ALUResult = a >> b;
            `OPco: 
            begin
                case(currentDst)
                    //cl
                    4'b0000: ; //dont need to implement for this assignment
                    //co
                    4'b0001: 
                        begin
                            cond = 8'b10000000;
                        
                            if (a == b)
                            begin
                                cond`eqPos = 1;
                                cond`lePos = 1;
                                cond`gePos = 1;
                            end
                            else
                            begin
                                if(a > b)
                                begin
                                    cond`gtPos = 1;
                                    cond`nePos = 1;
                                    cond`gePos = 1;
                                end
                                else
                                begin
                                    if(a < b)
                                    begin
                                        cond`ltPos = 1;
                                         cond`nePos = 1;
                                         cond`lePos = 1;
                                    end
                                end
                            end
                        end
                    default:
                        case(currentTsrc)
//                        //lo
//                        4'b0010: ; //just passthrough stage1srcvalue
//                        //nl
//                        4'b0011: ; //dont need to implement for this assignment
                        default: ALUResult = a;
                        endcase
                endcase
            end
            default: ALUResult = a;
        endcase
    end

endmodule

module processor(halt, reset, clk);
    output reg halt;
    input reset, clk;
    
    reg `word regfile `regsize;
    reg `word mainmem `memsize;
    
    reg `word ir, nextPC;
        //TsrcValue - Tsrc value returned right after a reg file read
        //srcValue - src value returned right after a reg file read
        //dstValue - dst value returned right after a reg file read
    reg `word TsrcValue, srcValue, dstValue;
    wire `opcodeSystemLen op; //entering operation code
    wire `regName regdst; //entering destination register address, if 0 then no write to registers occurs
    wire `word ALUResult; //ALU output
    reg `word pc; //program counter
    
    //intermediate buffer variables
    reg `opcodeSystemLen stage0op, stage1op, stage2op; //opcodes for each stage
        //stage*Tsrc - address of T source register
        //stage*src - address of source register
        //stage*dst - address of destination register
        //stage*regdst - also the address of desination register but if 0, then no write it to occur
    reg `regName stage0Tsrc, stage0src, stage0dst, stage0regdst;
    reg `regName stage1Tsrc, stage1src, stage1dst, stage1regdst;
    reg `regName stage2Tsrc, stage2src, stage2dst, stage2regdst;
        //stage*TsrcValue - regfile[stage*Tsrc]
        //stage*srcValue - regfile[stage*src]
        //stage*dstValue - regfile[stage*dst]
    reg `word stage1TsrcValue, stage1srcValue, stage1dstValue;
    reg `word stage2Value;
    
    wire [7:0] conditions; //comes from ALU
    
    reg isSquash, rrsquash; //bits used to control instruction squashing
    
    //sign extend immediate
    wire `word sexi;
    assign sexi = { (ir[7] ? 8'b11111111 : 8'b00000000), (ir `I) };
    
    reg `word sexi_delayed; //used for load immediate
    always@(posedge clk)
    begin
        sexi_delayed <= sexi;
    end
    
    always@(reset)begin
        halt = 0;
        pc = 0;
        stage0op = `OPnop;
        stage1op = `OPnop;
        stage2op = `OPnop;
        //$readmemh0(regfile);
        $readmemh("C:/Users/Tanner/ownCloud/School/EE480/Assignment3/assignment3/data.list",regfile);
        //$readmemh1(mainmem);
        $readmemh("C:/Users/Tanner/ownCloud/School/EE480/Assignment3/assignment3/text.list",mainmem);
    end
    
    //instruction decoder
    decode inst_decode(op, regdst, stage0op, ir);
    //arithmetic logic unit
    ALU inst_ALU(ALUResult, conditions, stage1op, stage1Tsrc, stage1dst, stage1srcValue, stage1TsrcValue);
    
    //instruction register
    always@(*) ir = mainmem[pc];
                                        
    //compute srcValue, with value forwarding
    always @(*) if (stage0op == `OPli) srcValue = sexi_delayed; // catch immediate for li
                else srcValue = ( (stage1regdst === 4'bXXXX) ? regfile[stage0src] : (((stage1regdst && (stage0src == stage1regdst)) ? ALUResult :
                                    ( (stage2regdst === 4'bXXXX) ? regfile[stage0src] : (((stage2regdst && (stage0src == stage2regdst)) ? stage2Value :
                                        regfile[stage0src]))))));
                                    
    //compute TsrcValue, with value forwarding
    always @(*) TsrcValue = ( (stage1regdst === 4'bXXXX) ? regfile[stage0Tsrc] : (((stage1regdst && (stage0Tsrc == stage1regdst)) ? ALUResult :
                                ( (stage2regdst === 4'bXXXX) ? regfile[stage0Tsrc] : (((stage2regdst && (stage0Tsrc == stage2regdst)) ? stage2Value :
                                    regfile[stage0Tsrc]))))));
    
    //compute dstval, with value forwarding
    always @(*) dstValue = ( (stage1regdst === 4'bXXXX) ? regfile[stage0dst] : (((stage1regdst && (stage0dst == stage1regdst)) ? ALUResult :
                               ( (stage2regdst === 4'bXXXX) ? regfile[stage0dst] : (((stage2regdst && (stage0dst == stage2regdst)) ? stage2Value :
                                    regfile[stage0dst]))))));
    
    //new pc
    always @(*) nextPC = (((stage1op == `OPbr) && (conditions[stage1dst] == 1)) ? (pc + sexi) : 
                            ( ((stage1op == `OPjr) && (conditions[stage1Tsrc] == 1)) ? (stage1dstValue) :
                            (pc + 1)));
    
    //IS squash - for jr and br
    always@(*)
    begin
        isSquash = (((stage1op == `OPbr) && (conditions[stage1dst] == 1)) || ((stage1op == `OPjr) && (conditions[stage1Tsrc] == 1)));
    end
    
    //TODO: check if needed, if so - why?
    //RR squash - 
    always@(*)
    begin
        rrsquash = isSquash;
    end
    
    //fetch instruction
    always@(posedge clk)
    begin
        if(!halt)
        begin
            //write stage 0's buffer
            stage0op <= (isSquash ? `OPnop : op);
            stage0regdst <= (isSquash ? 0 : regdst);
            stage0Tsrc <= ir `Tsrc;
            stage0src <= ir `src;
            stage0dst <= ir `dest;
            pc <= nextPC;
        end
    end
    
    //reg read
    always@(posedge clk)
    begin
        if(!halt)
        begin
            //load stage 1's information buffer
            stage1op <= (rrsquash ? `OPnop : stage0op);
            stage1regdst <= (rrsquash ? 0 : stage0regdst);
            stage1srcValue <= srcValue;
            stage1TsrcValue <= TsrcValue;
            stage1dstValue <= dstValue;
            stage1Tsrc <= stage0Tsrc;
            stage1src <= stage0src;
            stage1dst <= stage0dst;
        end
    end
    
    //ALU operation
    always@(posedge clk)
    begin
        if(!halt)
        begin
            //load stage 2's information buffer
            stage2op <= stage1op;
            stage2regdst <= stage1regdst;
            stage2Tsrc <= stage1Tsrc;
            stage2src <= stage1src;
            stage2dst <= stage1dst;
            stage2Value <= ( (stage1op == `OPsi) ? ( (stage1dstValue << 8)|({stage1src,stage1Tsrc}&8'b11111111)) : ((stage1op == `OPli) ? stage1srcValue : ((stage1op == `OPlo && stage1dst != 0 && stage1dst != 1 && stage1Tsrc == 2) ? mainmem[stage1srcValue] : ALUResult)));
            if (stage1op == `OPst && stage1dst != 0 && stage1dst != 1 && stage1Tsrc == 4) mainmem[stage1srcValue] <= stage1dstValue;
            if (stage1op == `OPsy) halt <= 1;
        end
    end
    
    reg `word previousstage2Value;
    //reg write
    always@(posedge clk)
    begin
        if(!halt)
        begin
                if (stage2regdst !=0) regfile[stage2regdst] <= stage2Value;
        end
    end
endmodule

module processor_tb();
    reg reset = 0;
    reg clk = 0;
    wire halted;
    integer i = 0;
    processor PE(halted, reset, clk);
    initial begin
        //$dumpfile;
        //$dumpvars(0, PE);
        #10 reset = 1;
        #10 reset = 0;
        while (!halted && (i < 200)) begin
            #10 clk = 1;
            #10 clk = 0;
            i=i+1;
        end
        $finish;
    end
endmodule
