library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.constants.all;

entity alu is
	Port(
		I_clk: in std_logic;
		I_en: in std_logic;
		I_imm: in std_logic_vector(XLEN-1 downto 0);
		I_dataS1: in std_logic_vector(XLEN-1 downto 0);
		I_dataS2: in std_logic_vector(XLEN-1 downto 0);
		I_reset: in std_logic := '0';
		I_aluop: in aluops_t;
		I_src_op1: in op1src_t;
		I_src_op2: in op2src_t;
		O_busy: out std_logic := '0';
		O_data: out std_logic_vector(XLEN-1 downto 0);
		O_PC: out std_logic_vector(XLEN-1 downto 0)
	);
end alu;

architecture Behavioral of alu is
	signal rdcycle: std_logic_vector(63 downto 0) := X"0000000000000000";
	signal rdinstr: std_logic_vector(63 downto 0) := X"0000000000000000";
	-- program counter
	signal pc: std_logic_vector(XLEN-1 downto 0) := XLEN_ZERO;
begin
	process(I_clk)
		variable aluop: aluops_t := ALU_NOP;
		variable newpc,pc4,pcimm,tmpval,op1,op2,sum: std_logic_vector(XLEN-1 downto 0);
		variable shiftcnt: std_logic_vector(4 downto 0);
		variable busy: boolean := false;
		variable sign: std_logic := '0';
		variable do_reset: boolean := false;
		variable eq,lt,ltu: boolean;
	begin

		-- increment cycle counter and check for reset on each clock
		if rising_edge(I_clk) then
			rdcycle <= std_logic_vector(unsigned(rdcycle) + 1);
			if(I_reset = '1') then
				do_reset := true;
				busy := false;
				pc <= XLEN_ZERO;
				O_PC <= XLEN_ZERO;
			else
				do_reset := false;
			end if;
		end if;
	
		-- main business here
		if rising_edge(I_clk) and I_en = '1' and not do_reset then

			
			case I_src_op1 is
				when SRC_S1 => op1 := I_dataS1;
				when SRC_PC => op1 := pc;
			end case;
			
			case I_src_op2 is
				when SRC_S2 => op2 := I_dataS2;
				when SRC_IMM => op2 := I_imm;
			end case;

			aluop := I_aluop;

			-- PC = PC + 4
			pc4 := std_logic_vector(unsigned(pc) + 4);
			pcimm := std_logic_vector(unsigned(pc) + unsigned(I_imm));
			newpc := pc4;
			
			
			-------------------------------
			-- generate output
			-------------------------------
			
			eq := op1 = op2;
			lt := signed(op1) < signed(op2);
			ltu := unsigned(op1) < unsigned(op2);
			sum := std_logic_vector(unsigned(op1) + unsigned(op2));

			case aluop is
		
				when ALU_ADD =>
					O_data <= sum;
				
				when ALU_SUB =>
					O_data <= std_logic_vector(unsigned(op1) - unsigned(op2));
					
				when ALU_AND =>
					O_data <= op1 and op2;
				
				when ALU_OR =>
					O_data <= op1 or op2;
					
				when ALU_XOR =>
					O_data <= op1 xor op2;
				
				when ALU_SLT =>
					O_data <= XLEN_ZERO;
					if lt then
						O_data(0) <= '1';
					end if;
				
				when ALU_SLTU =>
					O_data <= XLEN_ZERO;
					if ltu then
						O_data(0) <= '1';
					end if;
				
				when ALU_SLL | ALU_SRL | ALU_SRA =>
					if not busy then
						busy := true;
						tmpval := op1;
						shiftcnt := op2(4 downto 0);
					elsif shiftcnt /= "00000" then
						case aluop is
							when ALU_SLL => tmpval := tmpval(30 downto 0) & '0';
							when others =>
							if aluop = ALU_SRL then
								sign := '0';
							else
								sign := tmpval(31);
							end if;
							tmpval := sign & tmpval(31 downto 1);
						end case;
						shiftcnt := std_logic_vector(unsigned(shiftcnt) - 1);
					end if;
					
					if shiftcnt = "00000" then
						busy := false;
						O_data <= tmpval;
					end if;
					
				when ALU_OP2 =>
					O_data <= op2;
				
				when ALU_CYCLE =>
					O_data <= rdcycle(31 downto 0);
				
				when ALU_CYCLEH =>
					O_data <= rdcycle(63 downto 32);
				
				when ALU_INSTR =>
					O_data <= rdinstr(31 downto 0);
				
				when ALU_INSTRH =>
					O_data <= rdinstr(63 downto 32);
					
				when ALU_BEQ =>
					if eq then
						newpc := pcimm;
					end if;
					
				when ALU_BNE =>
					if not eq then
						newpc := pcimm;
					end if;
					
				when ALU_BLT =>
					if lt then
						newpc := pcimm;
					end if;
					
				when ALU_BGE =>
					if not lt then
						newpc := pcimm;
					end if;

				when ALU_BLTU =>
					if ltu then
						newpc := pcimm;
					end if;
					
				when ALU_BGEU =>
					if not ltu then
						newpc := pcimm;
					end if;

				when ALU_JAL =>
					newpc := pcimm;
					O_data <= pc4;
				
				when ALU_JALR =>
					newpc := sum; --std_logic_vector(unsigned(I_dataS1) + unsigned(I_imm));
					newpc(0) := '0';
					O_data <= pc4;

			
				when ALU_NOP =>
					null;
			end case;
			
			
			if busy then
				O_busy <= '1';
			else
				O_busy <= '0';
				-- we processed an instruction, increase counters
				rdinstr <= std_logic_vector(unsigned(rdinstr) + 1);
				pc <= newpc;
				O_pc <= newpc;
			end if;
			
		
		end if;
	end process;

end Behavioral;