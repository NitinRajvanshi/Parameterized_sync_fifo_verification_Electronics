🔄 FIFO Operation
Write

A write is accepted when the FIFO has available space.

Read

A read is accepted when the FIFO is not empty.

Simultaneous Read + Write

The FIFO supports simultaneous read and write operations.

When the FIFO is full, a simultaneous read can make room for a new write in the same clock cycle.

wire do_read  = rd_en && !empty;
wire do_write = wr_en && (!full || do_read);
🔁 Pointer Wrap-Around

The FIFO explicitly handles pointer wrap-around:

wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1'b1;
rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1'b1;

This allows the design to correctly support non-power-of-two depths.

Tested depths:

3
5
7
10
16

All tested configurations passed.

🧪 Verification Strategy

The verification environment was developed incrementally:

Directed Testing
       ↓
Randomized Testing
       ↓
Reference Model + Scoreboard
       ↓
Boundary Testing
       ↓
Functional Coverage
       ↓
SystemVerilog Assertions
       ↓
Bug Injection
       ↓
Class-Based Verification
       ↓
10,000-Transaction Regression
1️⃣ Directed Verification

Initial deterministic tests were created to establish basic FIFO functionality.

Test scenarios included:

Reset
Single write
Single read
Multiple writes
Multiple reads
FIFO full
FIFO empty
Simultaneous read/write
Boundary conditions
2️⃣ 🎲 Randomized Verification

Randomized stimulus was introduced after directed testing.

Random inputs included:

wr_en
rd_en
wr_data

The randomized testbench used an independent reference FIFO to determine expected behavior.

The scoreboard compared:

Expected Data  == DUT Data
Expected FULL  == DUT FULL
Expected EMPTY == DUT EMPTY

A 10,000-cycle regression completed with:

Errors = 0
3️⃣ 🧮 Reference Model + Scoreboard

The scoreboard maintains an independent FIFO model containing:

Reference Memory
Reference Write Pointer
Reference Read Pointer
Reference Occupancy
Error Counter

For every valid read:

Expected FIFO Data == DUT rd_data

The scoreboard also verifies FIFO status flags:

Expected FULL  == DUT FULL
Expected EMPTY == DUT EMPTY

This makes the testbench self-checking rather than relying only on waveform inspection.

4️⃣ 📊 Functional Coverage

Seven important functional scenarios were tracked:

#	Scenario
1	FIFO reaches FULL
2	FIFO reaches EMPTY
3	Simultaneous Read + Write
4	FULL + Write
5	EMPTY + Read
6	FULL + Simultaneous Read/Write
7	EMPTY + Simultaneous Read/Write

Final result:

Coverage bins hit      : 7 / 7
Functional coverage    : 100%
5️⃣ 🐛 Bug Injection

The verification environment was intentionally tested by introducing incorrect RTL implementations.

This validates that the testbench can actually detect design failures.

Bug #1 — FULL + Simultaneous Read/Write
Correct RTL
wire do_write = wr_en && (!full || do_read);
Injected Bug
wire do_write = wr_en && !full;

The randomized scoreboard detected the resulting DUT/reference-model mismatch.

The correct RTL was restored.

Bug #2 — Pointer Wrap-Around
Correct RTL
wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1'b1;
Injected Bug
wr_ptr <= wr_ptr + 1'b1;

The bug was exposed using non-power-of-two FIFO depths.

The correct implementation was restored.

Bug #3 — Incorrect FULL Flag
Correct RTL
assign full = (count == DEPTH);
Injected Bug
assign full = (count == DEPTH-1);

The SVA environment detected:

SVA FAILED: FULL flag incorrect

The correct RTL was restored.

6️⃣ 🛡️ SystemVerilog Assertions

SystemVerilog Assertions were added to verify important FIFO properties.

Occupancy Safety
property count_never_exceeds_depth;
    @(posedge clk)
    disable iff (!rst_n)
    count <= DEPTH;
endproperty
FULL Flag Correctness
property full_flag_correct;
    @(posedge clk)
    disable iff (!rst_n)
    full == (count == DEPTH);
endproperty
EMPTY Flag Correctness
property empty_flag_correct;
    @(posedge clk)
    disable iff (!rst_n)
    empty == (count == 0);
endproperty

Intentional assertion failures were successfully detected during bug-injection testing.

7️⃣ 🧩 Class-Based Verification

The final verification environment introduced transaction-based SystemVerilog classes.

                  ┌───────────────┐
                  │   Generator   │
                  └───────┬───────┘
                          │
                          ▼
                  ┌───────────────┐
                  │    Driver     │
                  └───────┬───────┘
                          │
                          ▼
                  ┌───────────────┐
                  │   FIFO DUT    │
                  └───────┬───────┘
                          │
                          ▼
                  ┌───────────────┐
                  │    Monitor    │
                  └───────┬───────┘
                          │
                          ▼
                  ┌───────────────┐
                  │  Scoreboard   │
                  └───────────────┘
Components
fifo_transaction
fifo_generator
fifo_driver
fifo_monitor
fifo_scoreboard

The architecture separates:

Stimulus
   ↓
Driving
   ↓
DUT
   ↓
Observation
   ↓
Checking
🏁 Final Regression

The final class-based regression used:

Data Width        : 8 bits
FIFO Depth        : 5
Transactions      : 10,000
Coverage          : 100%
Coverage Bins     : 7 / 7
Scoreboard Errors : 0
Final Result
╔══════════════════════════════════════╗
║                                      ║
║       FINAL REGRESSION PASSED        ║
║                                      ║
║       10,000 Transactions            ║
║       100% Functional Coverage       ║
║       0 Scoreboard Errors            ║
║                                      ║
╚══════════════════════════════════════╝
📁 Repository Structure
Parameterized_sync_fifo_verification_Electronics/
│
├── arm_verilog/
│   ├── fifo.v
│   ├── tb_fifo_directed.v
│   ├── tb_fifo_random.v
│   ├── tb_fifo_random_free.sv
│   ├── tb_fifo_sva.sv
│   └── tb_fifo_class.sv
│
├── README.md
└── LICENSE
🛠️ Tools & Technologies
Verilog
SystemVerilog
Verilator
EDA Playground
VCD Waveform Analysis
🎯 Verification Concepts Demonstrated
RTL Verification
├── Directed Testing
├── Randomized Testing
├── Reference Models
├── Scoreboarding
├── Boundary-Condition Testing
├── Functional Coverage
├── SystemVerilog Assertions
├── Bug Injection
├── Transaction-Based Verification
├── Generator / Driver / Monitor
└── Regression Testing
📈 What This Project Demonstrates

This project demonstrates practical understanding of how an RTL block can be verified using multiple complementary techniques.

Instead of relying on a single testbench, the verification strategy progressively increases confidence:

Basic Functionality
        ↓
Random Exploration
        ↓
Automatic Checking
        ↓
Coverage Measurement
        ↓
Assertion-Based Checking
        ↓
Bug Detection
        ↓
Scalable Class-Based Environment
🚧 Future Improvements

Possible extensions include:

 Mailbox-based communication
 SystemVerilog clocking blocks
 Interface modports
 Covergroups and coverpoints
 Additional SVA properties
 Full constrained-random verification with a supported solver
 UVM-based verification environment
 Formal verification
 Automated regression scripts
👨‍💻 Author
Nitin Kumar Rajvanshi

Digital Design | RTL Verification | SystemVerilog
