----------------------------------------------------------------------------------
--
-- Prova Finale (Progetto di Reti Logiche)
-- Prof. Fabio Salice - Anno 2021/2022
--
-- Pierluigi Negro (Codice Persona 10670080 Matricola 933774)
-- Marco Mol� (Codice Persona  Matricola )
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity project_reti_logiche is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start : in std_logic;
        i_data : in std_logic_vector(7 downto 0);
        o_address : out std_logic_vector(15 downto 0);
        o_done : out std_logic;
        o_en : out std_logic;
        o_we : out std_logic;
        o_data : out std_logic_vector (7 downto 0)
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
    type state_type is (
        IDLE,
        INIT,
        SET_WORD_NUMBER,
        COMPARE_WORD_COUNT,
        SET_BUFFER_IN,
        COMPUTE,
        WRITE_IN_BUFFER,
        COMPARE_BIT_COUNT,
        WRITE_MEMORY,
        COMPARE_HALF_WORD,
        DONE
    );

    type convolution_type is (S0, S1, S2, S3);
    
    signal curr_state, next_state : state_type;
    signal word_counter : integer range 0 to 255;
    signal word_number : integer range 0 to 255;
    signal buffer_out : std_logic_vector(7 downto 0);
    signal buffer_in : std_logic_vector(7 downto 0);
    signal bit_counter : integer range 0 to 3;
    signal convolution_state : convolution_type;
    signal pk1_out : std_logic;
    signal pk2_out : std_logic;
    signal half_word : std_logic;
    
begin
    process(i_clk, i_rst)
    -- The sequential process which asserts outputs and saves the values for the state
    begin
        if (i_rst = '1') then
            -- Asynchronously reset the machine
            curr_state <= IDLE;
            o_en <= '0';
            o_we <= '0';
        elsif rising_edge(i_clk) then
            case curr_state is
                when IDLE =>
                    if(i_start = '1') then
                        curr_state <= INIT;
                    end if;
                
                when INIT =>
                    word_counter <= 0;
                    o_en <= '1';
                    o_we <= '0';
                    o_address <= (others => '0');
                    bit_counter <= 0;
                    half_word <= '0';
                    convolution_state <= S0;
                    curr_state <= SET_WORD_NUMBER;
                
                when SET_WORD_NUMBER =>
                    word_number <= to_integer(unsigned(i_data));
                    o_en <= '0';
                    curr_state <= COMPARE_WORD_COUNT;

                when COMPARE_WORD_COUNT =>
                    if (word_counter < word_number) then
                        o_address <= std_logic_vector(to_unsigned(word_counter + 1, 16));
                        word_counter <= word_counter+1;
                        o_en <= '1';
                        curr_state <= SET_BUFFER_IN;

                    else
                        curr_state <= DONE;
                        
                    end if;

                when SET_BUFFER_IN =>
                    buffer_in <= i_data;
                    o_en <= '0';
                    curr_state <= COMPUTE;
                

                        
                    

        end if;
    end process;
end Behavioral;