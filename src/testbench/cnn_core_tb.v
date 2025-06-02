`timescale 1ns/10ps

`define TRACE_IN_FMAP 	"../inout/in_fmap.txt" 
`define TRACE_IN_WEIGHT "../inout/in_weight.txt"
`define TRACE_IN_BIAS 	"../inout/in_bias.txt"
`define TRACE_OT_RESULT "../inout/out_result_rtl.txt"

module cnn_core_tb ();

parameter   CNN_PIPE    = 5;  // no used, to use ctrl latency
parameter   CI          = 3;  // Number of Channel Input 
parameter   CO          = 16; // Number of Channel Output
parameter	KX			= 3;  // Number of Kernel X
parameter	KY			= 3;  // Number of Kernel Y

parameter   I_F_BW      = 8;  // Bit Width of Input Feature
parameter   W_BW        = 8;  // BW of weight parameter
parameter   B_BW        = 8;  // BW of bias parameter

parameter   M_BW        = 16; // I_F_BW * W_BW
parameter   AK_BW       = 20; // M_BW + log(KY*KX) Accum Kernel 
parameter   ACI_BW		= 22; // AK_BW + log (CI) Accum Channel Input
parameter   AB_BW       = 23; // ACI_BW + bias (#1). 
parameter   O_F_BW      = 23; // No Activation, So O_F_BW == AB_BW

parameter   O_F_ACC_BW  = 27; // for demo, O_F_BW + log (CO)

integer fp_f, fp_w, fp_b, fp_result;
integer kx, ky; 
integer ich, och; 

reg clk , reset_n, soft_reset;

reg     [CO*CI*KX*KY*W_BW-1 : 0] 	cnn_weight 	;
reg     [CO*B_BW-1    : 0]  		cnn_bias   	;
reg                               	in_valid  	;
reg     [CI*KX*KY*I_F_BW-1 : 0]  	in_fmap    	;
wire                              	w_ot_valid  ;
wire    [CO*O_F_BW-1 : 0]  			w_ot_fmap   ;


always
    #5 clk = ~clk;

initial begin

$display("initialize value [%d]", $time);
    reset_n 	= 1;
    clk     	= 0;
	soft_reset  = 0;
	cnn_weight 	= 0;
	cnn_bias   	= 0;
	in_valid  	= 0;
	in_fmap    	= 0;

$display("Reset! [%d]", $time);
# 10
   reset_n = 0;
# 10
   reset_n = 1;

$display("Read Input! [%d]", $time);
read_trace(cnn_weight, cnn_bias, in_fmap);
$display("Start! [%d]", $time);
@(posedge clk);
	in_valid = 1;

`ifdef USE_CHECKER
wait(w_ot_valid);
@(negedge clk);
$display("Write Output! [%d]", $time);
write_result(w_ot_fmap);
in_valid =0;
`endif

# 1000
$display("Finish! [%d]", $time);
$finish;
end

initial begin
  $dumpfile("dump.vcd");
  $dumpvars(1,u_cnn_core);
end
  
cnn_core u_cnn_core(
    
    .clk             (clk         	),
    .reset_n         (reset_n     	),
    .i_soft_reset    (soft_reset	),
    .i_cnn_weight    (cnn_weight	),
    .i_cnn_bias      (cnn_bias  	),
    .i_in_valid      (in_valid  	),
    .i_in_fmap       (in_fmap   	),
    .o_ot_valid      (w_ot_valid  	),
    .o_ot_fmap       (w_ot_fmap   	)      
    );


task read_trace;
	output     [CO*CI*KX*KY*W_BW-1 : 0] 	cnn_weight 	;
	output     [CO*B_BW-1    : 0]  			cnn_bias   	;
	output     [CI*KX*KY*I_F_BW-1 : 0]  	in_fmap    	;
	reg		   [7:0]						fmap, weight, bias;
	integer									read_och,read_ich, result,temp;
	reg 									fcheck;
	begin
		fp_f = $fopen(`TRACE_IN_FMAP, "r");
		fp_w = $fopen(`TRACE_IN_WEIGHT, "r");
		fp_b = $fopen(`TRACE_IN_BIAS, "r");
		fcheck = fp_f && fp_w && fp_b;
		if(fcheck)
			$display("success file open");
   		else 
			$finish;
		for (och = 0 ; och < CO; och = och+1)begin
			for(ich = 0; ich < CI; ich = ich+1)begin
				if(och == 0) begin
					result = $fscanf(fp_f,"(%d,%d) ", read_och, read_ich); 
					if(och != read_och) begin $finish; end
					if(ich != read_ich) begin $finish; end
				end
				result = $fscanf(fp_w,"(%d,%d) ", read_och, read_ich);
				if(och != read_och) begin $finish; end
				if(ich != read_ich) begin $finish; end

				for(ky = 0; ky < KY; ky = ky+1)begin
					for(kx = 0; kx < KX; kx = kx+1)begin
						if(och == 0) begin
							result = $fscanf(fp_f,"%d ", fmap);
							in_fmap[(och*CI*KY*KX+ ich*KY*KX+ ky*KX + kx)*I_F_BW +: I_F_BW] = fmap;
						end
						result = $fscanf(fp_w,"%d ", weight);
						cnn_weight[(och*CI*KY*KX+ ich*KY*KX+ ky*KX + kx)*W_BW +: W_BW] = weight;
					end
				end
				if(och == 0)
					result = $fscanf(fp_f,"\n",temp);
				result = $fscanf(fp_w,"\n",temp);
			end
			result = $fscanf(fp_b,"(%d,0) %d\n", read_och, bias);

			if(och != read_och) begin $finish; end
			cnn_bias[och*B_BW +: B_BW] = bias;
			result = $fscanf(fp_w,"\n",temp);
		end
		$fclose(fp_f);
		$fclose(fp_w);
		$fclose(fp_b);
	end
endtask

task write_result;
	input    [CO*O_F_BW-1 : 0]  			i_ot_fmap   ;
	integer									read_och,read_ich, result,temp;
	reg [O_F_BW-1 : 0]	ot_fmap;
	begin
		fp_result = $fopen(`TRACE_OT_RESULT, "w");
		for (och = 0 ; och < CO; och = och+1)begin
			ot_fmap = i_ot_fmap[och*O_F_BW +: O_F_BW];
			$fdisplay(fp_result,"(%0d,0) %0d", och, ot_fmap);
			$display("(%0d,0) %d", och, ot_fmap);
		end
		$fclose(fp_result);
	end
endtask

endmodule