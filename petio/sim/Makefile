GHDL ?= ghdl
GHDLFLAGS := --std=08 -fsynopsys
SCRIPT ?=
ROM ?= rom.bin
VIEWER ?= gtkwave

all: via pia uart

via:
	$(GHDL) -a $(GHDLFLAGS) ../via6522.vhd reg_script_pkg.vhd tb_via6522.vhd
	$(GHDL) -e $(GHDLFLAGS) tb_via6522
	$(GHDL) -r $(GHDLFLAGS) tb_via6522 -gscript_file=$(if $(SCRIPT),$(SCRIPT),scripts/via_script.txt) --vcd=via.vcd
	$(VIEWER) via.vcd via.gtkw

pia:
	$(GHDL) -a $(GHDLFLAGS) ../pia6520.vhd reg_script_pkg.vhd tb_pia6520.vhd
	$(GHDL) -e $(GHDLFLAGS) tb_pia6520
	$(GHDL) -r $(GHDLFLAGS) tb_pia6520 -gscript_file=$(if $(SCRIPT),$(SCRIPT),scripts/pia_script.txt) --vcd=pia.vcd

uart:
	$(GHDL) -a $(GHDLFLAGS) uart_top_sim.vhd ../uart_shell.vhd reg_script_pkg.vhd tb_uart_shell.vhd
	$(GHDL) -e $(GHDLFLAGS) tb_uart_shell
	$(GHDL) -r $(GHDLFLAGS) tb_uart_shell -gscript_file=$(if $(SCRIPT),$(SCRIPT),scripts/uart_script.txt) --vcd=uart.vcd

clean:
	rm -f work-obj08.cf

shell_cpu:
	$(GHDL) -a $(GHDLFLAGS) \
		../select.vhd \
		../pia6520.vhd \
		../via6522.vhd \
		../ieeedir.vhd \
		../uart_shell.vhd \
		../Shell.vhd \
		cpu6502.vhd \
		tb_shell_cpu.vhd
	$(GHDL) -e $(GHDLFLAGS) tb_shell_cpu
	$(GHDL) -r $(GHDLFLAGS) tb_shell_cpu \
		-grom_file=$(ROM) \
		--vcd=shell_cpu.vcd
