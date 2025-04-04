import esdl;
import esdl.intf.verilator.verilated;
import esdl.intf.verilator.trace;
import uvm;
import std.stdio;
import std.string: format;

// Virtual Interface
class hs_inf: VlInterface 
{
	Port!(Signal!(ubvec!1)) clk_a,clk_b;
	Port!(Signal!(ubvec!1)) rst;
	VlPort!32 Wr_port, Rd_port;
	VlPort!1 REQ,ACK;
}

// Sequence item
class seq_item: uvm_sequence_item 
{
	mixin uvm_object_utils;

	this(string name="seq_item") {
		super(name);
	}

	@UVM_DEFAULT {
		@rand ubvec!32 Wr_port;
		ubvec!32 Rd_port;
		ubvec!1 rst,REQ,ACK;
	}

	constraint! q{
		Wr_port>=224;
		Wr_port<=41123;
	} wr_data;

	void print(string component) {
		writeln("[%s] rst=%ub data_in=%d REQ=%ub ACK=%ub data_out=%d",component, rst, Wr_port, REQ, ACK, Rd_port);
	}
}

// Sequence
class hs_seq: uvm_sequence!seq_item 
{
	mixin uvm_object_utils;
	seq_item xtn;

	this(string name="hs_seq") {
		super(name);
	}

	override void pre_body() {
		super.pre_body();
	}

	override void body() {
		for(int i=0; i<=10; ++i) {
			xtn=seq_item.type_id.create("xtn");
			start_item(xtn);
			finish_item(xtn);
		}
	}
}

// Sequencer
class hs_sqr: uvm_sequencer!seq_item 
{
	mixin uvm_component_utils;

	this(string name="hs_sqr", uvm_component parent=null) {
		super(name,parent);
	}
}

// Driver
class driver: uvm_driver!seq_item 
{
	mixin uvm_component_utils;

	hs_inf vif;
	seq_item item;

	this(string name="driver", uvm_component parent=null) {
		super(name,parent);
	}

	override void build_phase(uvm_phase phase) {
		uvm_config_db!hs_inf.get(this,"","hs_in",vif);
		uvm_info(get_type_name(),"entering build phase", UVM_LOW);
	}

	void wait_n_cycles(int n) {
		for(int i=0; i!=n; ++i) {
			wait(vif.clk_a.posedge());
		}
	}

	void drive(seq_item xtn) {
		if(vif.rst==0) {
			xtn.Wr_port=225; // initial write data after rst becomes 0
		}
		if(vif.ACK==1) {
			wait_n_cycles(4);
			xtn.randomize();
		}
	}

	override void run_phase(uvm_phase phase) {
		super.run_phase(phase);
		while(true) {
			item=seq_item.type_id.create("item");
			seq_item_port.get_next_item(item);
			drive(item);
			wait(vif.clk_a.posedge());
		    vif.Wr_port=item.Wr_port;
		    vif.rst=item.rst;
			seq_item_port.item_done();
		}
	}
}

// monitor
class monitor: uvm_monitor {
	mixin uvm_component_utils;

	hs_inf vif;
	seq_item item;

	this(string name="monitor", uvm_component parent=null) {
		super(name,parent);
	}

	@UVM_BUILD {
		uvm_analysis_port!seq_item mon2ref;
		uvm_analysis_port!seq_item mon2sb;
	}

	override void build_phase(uvm_phase phase) {
		uvm_config_db!hs_inf.get(this,"","hs_out",vif);
		uvm_info(get_type_name(), "entering build phase", UVM_LOW);
	}

	void drive_in(seq_item item) {
		wait(vif.clk_a.posedge());
		item.Wr_port=vif.Wr_port;
		item.rst=vif.rst;
	}

	void drive_out(seq_item item) {
		wait(vif.clk_b.posedge());
		item.Rd_port=vif.Rd_port;
		item.REQ=vif.REQ;
		item.ACK=vif.ACK;
	}

	override void run_phase(uvm_phase phase) {
		super.run_phase(phase);
		while(true) {
			item=seq_item.type_id.create("item");
			drive_in(item);
			drive_out(item);
		    mon2ref.write(item);
		    mon2sb.write(item);
		}
	}
}


// Agent
class agent: uvm_agent {
	mixin uvm_component_utils;

	this(string name="agent", uvm_component parent=null) {
		super(name,parent);
	}

	driver drv;
	monitor mon;
	hs_sqr sqr;

	override void build_phase(uvm_phase phase) {
		drv=driver.type_id.create("drv",this);
		mon=monitor.type_id.create("mon",this);
		sqr=hs_sqr.type_id.create("sqr",this);
		uvm_info(get_type_name(),"entering build phase",UVM_LOW);
	}

	override void connect_phase(uvm_phase phase) {
		drv.seq_item_port.connect(sqr.seq_item_export);
	}
}

// Reference model
class hs_ref: uvm_component 
{
	mixin uvm_component_utils;

	ubvec!1 trigger;
	ubvec!32 q,comp;
	uint cnt;
	seq_item expt;

	this(string name="hs_ref", uvm_component parent=null) {
		super(name,parent);
	}

	@UVM_BUILD {
		uvm_analysis_port!seq_item ref2sb;
		uvm_analysis_imp!(hs_ref, write) mon2ref;
	}

	override void build_phase(uvm_phase phase) {
		uvm_info(get_type_name(),"entering build phase",UVM_LOW);
	}

	void assign_delay(ubvec!32 a, ubvec!32 b) {
		wait(10.nsec);
		b=a;
	}

	void assign_delay_40(ubvec!1 a, ubvec!1 b) {
		wait(40.nsec);
		b=a;
	}

	void write(seq_item item) {
		assign_delay(q,item.Wr_port);
		expt=seq_item.type_id.create("expt");
		if(item.rst) {
			expt.Rd_port=0;
			expt.ACK=0;
			trigger=0;
		}
		else {
			for(int i=0; i!=32; ++i) {
				comp[i]=(item.Wr_port[i] != q[i]);
			}
			trigger=comp[0];
			for(int i=1; i!=32; ++i) {
				trigger |=comp[i];
			}
		}
		if(item.rst || cnt==3) cnt=0;
		else if(expt.REQ) cnt++;
		else cnt=cnt;
		if(item.rst || cnt==3) expt.REQ=0;
		else if(trigger) expt.REQ=1;
		else expt.REQ=expt.REQ; 
		expt.Rd_port=q;
		assign_delay_40(expt.ACK,expt.REQ);
		ref2sb.write(expt);
	}
}

// Scoreboard
class scoreboard: uvm_scoreboard 
{
	mixin uvm_component_utils;
	seq_item expt,act;

	this(string name="scoreboard", uvm_component parent=null) {
		super(name,parent);
	}

	@UVM_BUILD {
		uvm_analysis_imp!(scoreboard, write_ref) ref2sb;
		uvm_analysis_imp!(scoreboard, write_mon) mon2sb;
	}

	override void build_phase(uvm_phase phase) {
		uvm_info(get_type_name(),"entering build phase",UVM_LOW);
	}

	void write_ref(seq_item expt) {
		this.expt=expt;
	}

	void write_mon(seq_item act) {
		this.act=act;
	}

	void compare() {
		if(expt.Rd_port !is act.Rd_port)
			uvm_info("Read data mismatch",format("Expected data = %d Actual data = %d",expt.Rd_port,act.Rd_port),UVM_LOW);
		else 
			uvm_info("Data match","Read data match",UVM_LOW);
		if(expt.REQ !is act.REQ)
			uvm_info("REQ signal error",format("Expected REQ = %d Actual REQ = %d",expt.REQ,act.REQ),UVM_LOW);
		else 
			uvm_info("Data match","REQ signal match",UVM_LOW);
		if(expt.ACK !is act.ACK)
			uvm_info("ACK signal error",format("Expected ACK = %d Actual ACK = %d",expt.Rd_port,act.Rd_port),UVM_LOW);
		else 
			uvm_info("Data match","ACK signal match",UVM_LOW);
	}

	override void run_phase(uvm_phase phase) {
		expt=seq_item.type_id.create("expt");
		act=seq_item.type_id.create("act");
		if(expt !is null && act !is null) {
			compare();
		}
	}
}

// Environment
class hs_env: uvm_env 
{
	mixin uvm_component_utils;

	agent agt;
	scoreboard sb;
	hs_ref refm;

	this(string name="hs_env", uvm_component parent=null) {
		super(name,parent);
	}

	override void build_phase(uvm_phase phase){
		agt=agent.type_id.create("agt",this);
		sb=scoreboard.type_id.create("sb",this);
		refm=hs_ref.type_id.create("refm",this);
		uvm_info(get_type_name(), "entering build phase", UVM_LOW);
	}

	override void connect_phase(uvm_phase phase) {
		super.connect_phase(phase);
		agt.mon.mon2ref.connect(refm.mon2ref);
		agt.mon.mon2sb.connect(sb.mon2sb);
		refm.ref2sb.connect(sb.ref2sb);
	}
}

// test class
class hs_test: uvm_test 
{
	mixin uvm_component_utils;
	hs_env env;
	hs_seq seq;

	this(string name="test", uvm_component parent=null) {
		super(name,parent);
	}

	override void build_phase(uvm_phase phase){
		env=hs_env.type_id.create("env",this);
		uvm_info(get_type_name(), "entering build phase", UVM_LOW);
	}
	override void run_phase(uvm_phase phase) {
		seq=hs_seq.type_id.create("hs_seq");
		phase.raise_objection(this);
		writeln("sequence_Started");
		seq.start(env.agt.sqr);
		phase.drop_objection(this);
	}
}

// Top-level Testbench
class Top: Entity 
{
  import Vhandshake_sync_euvm;
  import esdl.intf.verilator.verilated;

  VerilatedVcdD _trace;
  Signal!(ubvec!1) clk_a, clk_b;
  Signal!(ubvec!1) rst;
  DVhandshake_sync dut;
  hs_inf hsIntf;

  void opentrace(string vcdname) {
    if (_trace is null) {
      _trace = new VerilatedVcdD();
      dut.trace(_trace, 99);
      _trace.open(vcdname);
    }
  }

  void closetrace() {
    if (_trace !is null) {
      _trace.close();
      _trace = null;
    }
  }

  override void doConnect() {
    hsIntf.clk_a(clk_a);
    hsIntf.clk_b(clk_b);
    hsIntf.rst(rst);
    hsIntf.Wr_port(dut.Wr_port);
    hsIntf.Rd_port(dut.Rd_port);
    hsIntf.REQ(dut.REQ);
    hsIntf.ACK(dut.ACK);
  }

  override void doBuild() {
    dut = new DVhandshake_sync();
    traceEverOn(true);
    opentrace("handshake_sync.vcd");
  }

  Task!stimulateClockA stimulateClockATask;
  Task!stimulateClockB stimulateClockBTask;
  Task!stimulateReset stimulateResetTask;

  void stimulateClockA() {
    clk_a = false;
    for (size_t i = 0; i != 200; ++i) {
      clk_a = !clk_a;
      wait(5.nsec);
    }
  }

  void stimulateClockB() {
    clk_b = false;
    for (size_t i = 0; i != 200; ++i) {
      clk_b = !clk_b;
      wait(10.nsec);
    }
  }

  void stimulateReset() {
    rst = true;
    wait(10.nsec); // Two clk_a pulses (each 5ns)
    rst = false;
  }
}

// EUVM Testbench
class uvm_hs_tb: uvm_tb 
{
  Top top;

  override void initial() {
    uvm_config_db!(hs_inf).set(null, "*", "hs_in", top.hsIntf);
    uvm_config_db!(hs_inf).set(null,"*", "hs_out", top.hsIntf);
  }
}

void main(string[] args) {
  uint random_seed;
  CommandLine cmdl = new CommandLine(args);

  if (cmdl.plusArgs("random_seed=" ~ "%d", random_seed))
    writeln("Using random_seed: ", random_seed);
  else 
    random_seed = 1;

  auto tb = new uvm_hs_tb;
  tb.multicore(0, 1);
  tb.elaborate("tb", args);
  tb.set_seed(random_seed);
  tb.start();
}
