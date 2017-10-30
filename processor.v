`define word		[15:0]
`define halfword	[7:0]
`define opcode      [15:12]
`define dest        [11:8]
`define src         [7:4]
`define Tsrc        [3:0]
`define state       [4:0]
`define start       5'b11111
`define start1      5'b11110
`define ALopCompletion 5'b11101
`define regsize		[15:0]
`define memsize 	[65535:0]
`define width		16;
`define aluc		[2:0]
`define regc		[1:0]
`define regsel		[3:0]

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

module processor_tb();
    reg clk, reset;
    
    wire halt;
    
    initial begin
        //$dumpfile;
        reset = 0;
        clk = 0;
        #10
        reset = 1;
        #10 reset = 0;
    end
    
    always begin
        #50 clk = ~clk;
    end
    
    processor uut(halt, reset, clk);
    
    //$dumpvars(0,uut);
    
    always@(posedge halt)
    begin
        $finish;
    end
    
endmodule

module processor(halt, reset, clk);
	output reg halt;
	input reset, clk;
	reg `word pc;
	reg `word MDR_out;
	
	//======controller comm busses=======
	//input
	   //current opcode
	   //clk
	//output
	wire IorD, MemtoReg, ALUSrcA; 
    wire [1:0] ALUSrcB, PCSource;
	
	//======mainmem comm busses======
	//input
	reg `word memAddress;
	wire `word memDataIn; //data to write to main mem
	wire memRead;
	wire memWrite;
	//output
	wire `word memDataOut;
	
	//======instruction register comm busses=======
    //input
    //see memDataOut
    wire IRWrite;
    //output
    wire [3:0] currentOpcode, currentDst, currentSrc, currentTsrc;
	
	//======reg file comm busses======
	wire RegDst;
	//input
	wire [3:0] readReg1;
	wire [3:0] readReg2;
	reg [3:0] writeReg;
	wire writeToRegCommand;
	reg `word writeData;
    //output
    wire `word readRegData1;	
	wire `word readRegData2;
	
	//=====ALU comm busses=====
	//input
	reg `word a, b;
	wire `opcode ALUControl;
	reg `word RegAForALUInput, RegBForALUInput;
	//output
	wire `word ALUOut;
	wire `word ALUResult;
	
	//=====ALU controller comm busses=====
	//input
	wire ALUOp; //from controller to alu controller
	wire [3:0]OpFromController;
	//output	
    wire brEnable;
    
    initial 
    begin
        halt = 0;
        pc = 0;
        memAddress = pc;
        MDR_out = 0;
    end
    
	always@(reset) begin
       halt = 0;
       pc = 0;
       memAddress = pc;
    end
	
	//mux to choose memory address
	always @(IorD, ALUOut, pc)
	begin
	   if(IorD == 1)
	       memAddress <= ALUOut;
	    else
	       memAddress <= pc;
	end
	
	controller controller(IorD, memRead, memWrite, MemtoReg, RegDst, writeToRegCommand, ALUSrcA, ALUSrcB, ALUOp, OpFromController, PCSource, PCWrite, IRWrite, reset, clk, currentOpcode, currentDst, currentSrc, currentTsrc);

    //mux to choose how the PC gets set for the next instruction processing
    always@(posedge clk)
    begin
        if(PCWrite == 1)
        begin
            case(PCSource)
                0: pc <= ALUResult;//instant alu result
                1: 
                begin
                    if(currentOpcode !== `OPbr)
                        begin
                            pc <= ALUOut; //aluout clocked register
                        end
                    else
                        begin
                            if(brEnable)
                                pc <= ALUOut; //if condition is true
                            else
                                pc <= pc + 1; //fall through
                        end
                end
                2: ;//?????????
                default: halt = 1;
            endcase  
        end
    end
	
	mainMem mainMem(memDataOut, reset, clk, memAddress, memRead, memWrite, memDataIn);
	IR IR(currentOpcode, currentDst, currentSrc, currentTsrc, IRWrite, reset, clk, memDataOut);
	
	//check if a sy instruction was loaded. if so, then halt
	always@(*)
	begin
	   if(currentOpcode == `OPsy)
	   begin
	       halt = 1;
	       
	   end
	end
	
	//connecting some wires together. wanted different names to better organize code
   assign readReg1 = currentSrc;
   assign readReg2 = currentTsrc;
   
   always@(posedge clk)
   begin
        MDR_out = memDataOut; //MDR
   end
    
	
	always@(RegDst)
	begin
	   if(RegDst == 1)
           writeReg = currentDst;
        //else
           //??????????
	end

    //mux to control whether to write memory data to dest register to right aluout to dest register
    always@(*)
	begin
	   if(MemtoReg == 1)
           writeData <= MDR_out;
        else
           writeData <= ALUOut;
	end
	
	regfile regfile(readRegData1, readRegData2, reset, clk, readReg1, readReg2, writeReg, writeToRegCommand, writeData);
	
	//reg read registers
	always@(posedge clk)
	begin
	   RegAForALUInput <= readRegData1;
	   RegBForALUInput <= readRegData2;
	end
	
	
	//mux to choose whether ALU input A is the PC or register data from regfile
	always@(ALUSrcA)
	begin
	   if(ALUSrcA == 1)
	       a <= RegAForALUInput;
	   else
	       a <= pc;
	end
	
	reg [7:0] tempFor8bitImmed;
	always@(*)
	begin
	   tempFor8bitImmed = {currentSrc, currentTsrc};
	end
	
	//mux to choose the source of ALU input B
	always@(ALUSrcB)
    begin
       case(ALUSrcB)
            0: b <= RegBForALUInput; //input B is register data from the regfile
            1: b <= 1; //increment PC by 1
            2: b <= { {8{tempFor8bitImmed[7]}}, tempFor8bitImmed[7:0] };//sign extend the immediate
            3: b <= tempFor8bitImmed;//for label in a branch
            default: halt = 1;
       endcase
    end
        
    ALUcontroller ALUcontroller(ALUControl, ALUOp, clk, OpFromController, currentOpcode);
	alu ALU(ALUResult, ALUOut, clk, a, b, currentDst, currentSrc, currentTsrc, brEnable, ALUControl);
	
		
endmodule

//-----------------------------------------------------control logic---------------------------
module controller(IorD, memRead, memWrite, MemtoReg, RegDst, writeToRegCommand, ALUSrcA, ALUSrcB, ALUOp,OpFromController, PCSource, PCWrite, IRWrite, reset, clk, currentOpcode, currentDst, currentSrc, currentTsrc);
    output reg IorD, memRead, memWrite, MemtoReg, RegDst, writeToRegCommand, ALUSrcA, ALUOp, PCWrite, IRWrite; 
    output reg [1:0] ALUSrcB, PCSource;
    output reg [3:0] OpFromController;
    
    input clk, reset;
    input [3:0] currentOpcode, currentDst, currentSrc, currentTsrc;
    
    reg `state s;
    
    initial s = `start;
    
    initial
    begin
        IorD <= 0;
        memRead <= 0;
        memWrite <= 0;
        MemtoReg <= 0;
        RegDst <= 0;
        writeToRegCommand <= 0;
        ALUSrcA <= 0;
        ALUOp <= 0;
        PCWrite <= 0;
        IRWrite <= 0;
        ALUSrcB <= 2'b00;
        PCSource <= 2'b00;
        ALUOp <= 1; //Force an operation upon the ALU
        OpFromController <= `OPad; //set an operation to force on the ALU
    end
    
    always@(reset)
    begin
        s = `start;
    end
    
    always@(posedge clk)
    begin
//        IorD <= 0;
//        memRead <= 0;
//        memWrite <= 0;
//        MemtoReg <= 0;
//        RegDst <= 0;
//        writeToRegCommand <= 0;
//        ALUSrcA <= 0;
//        ALUOp <= 0;
//        PCWrite <= 0;
//        IRWrite <= 0;
//        ALUSrcB <= 2'b00;
//        PCSource <= 2'b00;
        case(s)
            `start:
                //INSTRUCTION FETCH
                begin
                    RegDst <= 0;
                    writeToRegCommand <= 0;
                    MemtoReg <= 0;
                
                    memRead <= 1; //enable memory reading
                    IRWrite <= 1; //enable IR writing
                    
                    ALUSrcB <= 2'b01; //set ALU input B to 1 to incrememnt the PC to 1
                    ALUSrcA <= 0; //redundant but set the ALU input A to the PC value
                    ALUOp <= 1; //Force an operation upon the ALU
                    OpFromController <= `OPad; //set an operation to force on the ALU
                    
                    PCSource <= 2'b00;
                    PCWrite <= 1; //enable PC writing

                    s <= `start1;
                end
                
           `start1:
                //DECODE AND REGISTER FETCH
                begin
                    //read src registers
                    memRead <= 1;
                    IRWrite <= 0;
                    
                    ALUSrcB <= 2'b11;
                    ALUSrcA <= 0;
                    ALUOp <= 0;
                    
                    PCSource <= 2'b00;
                    PCWrite <= 0;
                    
                    //calculate 
                    s <= currentOpcode;
                end
           //EXECUTION
           `OPad: 
                begin
                    
                    memRead <= 0;
                    
                    ALUSrcB <= 2'b00;
                    ALUSrcA <= 1;
                    ALUOp <= 0;
                    
                    PCWrite <= 0;
                    
                   s <= `ALopCompletion;
                end  
           `OPan: 
                 begin
                       
                     memRead <= 0;
                     
                     ALUSrcB <= 2'b00;
                     ALUSrcA <= 1;
                     ALUOp <= 0;
                     
                     PCWrite <= 0;
                                         
                       s <= `ALopCompletion;
                 end
           `OPbr:
                begin
                    ALUSrcA <= 1;
                    ALUSrcB <= 2'b00;
                    ALUOp <= 0;
                    PCSource <= 2'b11;
                end
           `OPco: 
                begin
                    case(currentDst)
                        //cl
                        4'b0000: ; //dont need to implement for this assignment
                        //co
                        4'b0001: 
                            begin
                                memRead <= 0;
                                                
                                ALUSrcB <= 2'b00;
                                ALUSrcA <= 1;
                                ALUOp <= 0;
                                
                                PCWrite <= 0;
                                
                                //IRWrite <= 1;
                                
                                s <= `start; //writes to an internal register in the ALU
                            end
                        default:
                            case(currentTsrc)
                            //lo
                            4'b0010: ;
                            //nl
                            4'b0011: ; //dont need to implement for this assignment
                            //st
                            4'b0100: ;
                            endcase
                    endcase
                end
           `OPeo:
                begin
                       
                       s <= `start;
                end
           `OPli:
                begin
                       
                       s <= `start;
                end
           `OPmi:
                begin
                       
                       s <= `start;
                end
           `OPno:
                begin
                       
                       s <= `start;
                end
           `OPor:
                begin
                       
                       s <= `start;
                end
           `OPsi:
                begin
                       
                       s <= `start;
                end
           `OPsr:
                begin
                       
                       s <= `start;
                end
            `ALopCompletion:
                begin
                    IorD <= 0;
                    memRead <= 0;
                    memWrite <= 0;
                    ALUSrcA <= 0;
                    ALUOp <= 0;
                    PCWrite <= 0;
                    IRWrite <= 0;
                    ALUSrcB <= 2'b00;
                    PCSource <= 2'b00;
                        
                        
                    RegDst <= 1;
                    writeToRegCommand <= 1;
                    MemtoReg <= 0;
                    
                    //IRWrite <= 1;
                    
                    s <= `start;
                end
        endcase
     end
    
    
endmodule

module ALUcontroller(ALUOperation, ALUOp, clk, OpFromController, currentOpcode);
    output reg [3:0] ALUOperation;
    input ALUOp, clk;
    input [3:0] currentOpcode, OpFromController;
    
    always@(ALUOp)
    begin
        if(ALUOp == 1)
            ALUOperation <= OpFromController; //controller forcing an operation upon the ALU
        else
            ALUOperation <= currentOpcode; //change operation to current instruction
    end

endmodule

//----------------------ALU---------------------------
module alu(ALUResult, ALUOut, clk, a, b, currentDst, currentSrc, currentTsrc, brEnable, ALUOperation);
	input `word a, b;
	input clk;
	input [3:0] ALUOperation;
	input [3:0] currentDst, currentSrc, currentTsrc;
	
	output reg `word ALUOut;
	output reg `word ALUResult;
	output reg brEnable;
	
	always@(posedge clk)
	begin
	   ALUOut <= ALUResult;
	end
	
	initial ALUOut = 0;
	
	reg [7:0] cond;
	
	initial cond = 8'b10000000; //t gt ge ne eq le lt f
	
	reg test = 0;
	
	always@(ALUOperation, a, b) begin
	//always@(posedge clk) begin
	   case(ALUOperation)
	       `OPad:
	       begin
	       test = 1;
	        ALUResult <= a+b;
	        end
	       `OPan: ALUResult <= a&b;
	       `OPeo: ALUResult <= a^b;
	       `OPli: ; //???????????
	       `OPmi: ; //???????????
	       `OPno: ALUResult <= !a;
	       `OPor: ALUResult <= a|b;
	       `OPsi: ; //???????????
	       `OPsr: ALUResult <= a >> b;
	       `OPbr:
            begin
               ALUResult <= b; //address to label
               if(cond[currentDst-7] == 1) //currentDst is the condition register for branch
                   brEnable <= 1;
               else
                   brEnable <= 0;
            end
           `OPco: 
            begin
                    case(currentDst)
                        //cl
                        4'b0000: ; //dont need to implement for this assignment
                        //co
                        4'b0001: 
                            begin
                            cond <= 8'b10000000;
                            
                            if (a == b)
                            begin
                                cond`eqPos <= 1;
                                cond`lePos <= 1;
                                cond`gePos <= 1;
                            end
                            else
                            begin
                                if(a > b)
                                begin
                                    cond`gtPos <= 1;
                                    cond`nePos <= 1;
                                    cond`gePos <= 1;
                                end
                                else
                                begin
                                    if(a < b)
                                    begin
                                        cond`ltPos <= 1;
                                         cond`nePos <= 1;
                                         cond`lePos <= 1;
                                    end
                                end
                            end
                            end
                        default:
                            case(currentTsrc)
                            //lo
                            4'b0010: ;
                            //nl
                            4'b0011: ; //dont need to implement for this assignment
                            //st
                            4'b0100: ;
                            endcase
                    endcase
            end
	       default: ;
	   endcase
	end
endmodule

//--------------------regfile------------------------
module regfile(readRegData1, readRegData2, reset, clk, readReg1, readReg2, writeReg, writeToRegCommand, writeData);
    input clk, reset;
    input [3:0] readReg1, readReg2, writeReg;
    input writeToRegCommand;
    input `word writeData;
    
    output reg `word readRegData1, readRegData2;
     
    reg `word regfileArray `regsize; //register file
	
	initial begin
	   //$readmemh0(regfileArray);
	   $readmemh("C:/Users/Tanner/ownCloud/School/EE480/HW2MultiBus/Assignment2/data.list",regfileArray);
	end
	
	always@(reset) begin
	   //$readmemh0(regfileArray);
	   $readmemh("C:/Users/Tanner/ownCloud/School/EE480/HW2MultiBus/Assignment2/data.list",regfileArray);
    end
	
	always@(posedge clk)
	begin
	   readRegData1 <= regfileArray[readReg1];
	   readRegData2 <= regfileArray[readReg2];
	   if(writeToRegCommand == 1)
            regfileArray[writeReg] <= writeData;
	end
        
//    always@(writeReg)
//    begin
//        if(RegWriteCommand == 1)
//            regfileArray[writeReg] = writeData;
//    end
	
	
endmodule

//-----------------------------------------------------main mem--------------------------------
module mainMem(memDataOut, reset, clk, memAddress, memRead, memWrite, memDataIn);
	input clk, reset;
	input memRead, memWrite;
	input `word memDataIn;
	input `word memAddress;
	
	output reg `word memDataOut;
	
	reg `word mainmemory `memsize;
	
	initial
	begin
	   //$readmemh1(mainmemory);
	   $readmemh("C:/Users/Tanner/ownCloud/School/EE480/HW2MultiBus/Assignment2/text.list",mainmemory);
	   #1;
	   memDataOut = mainmemory[memAddress];
	end
	
	always@(reset) begin
           //$readmemh1(mainmemory);
           $readmemh("C:/Users/Tanner/ownCloud/School/EE480/HW2MultiBus/Assignment2/text.list",mainmemory);
    end
        
	always@(posedge clk)
	begin
	   if(memWrite == 1)
	       mainmemory[memAddress] <= memDataIn;
	   else
       begin
           if(memRead == 1)
               memDataOut <= mainmemory[memAddress];
       end
	end
	
endmodule

//instruction register
module IR(currentOpcode, currentDst, currentSrc, currentTsrc, IRWrite, reset, clk, memDataOut);
    input `word memDataOut;
    input clk, IRWrite, reset;
    
    output reg [3:0] currentOpcode, currentDst, currentSrc, currentTsrc;
    
    initial
    begin
        currentOpcode <= memDataOut`opcode;
        currentDst <= memDataOut`dest;
        currentSrc <= memDataOut`src ;
        currentTsrc <= memDataOut`Tsrc;
    end
    
    always@(reset)
    begin
        currentOpcode <= memDataOut`opcode;
        currentDst <= memDataOut`dest;
        currentSrc <= memDataOut`src ;
        currentTsrc <= memDataOut`Tsrc;
    end
    
    always@(posedge clk)
    begin
        if(IRWrite)
        begin
            currentOpcode <= memDataOut`opcode;
            currentDst <= memDataOut`dest;
            currentSrc <= memDataOut`src ;
            currentTsrc <= memDataOut`Tsrc;
        end
    end
endmodule
