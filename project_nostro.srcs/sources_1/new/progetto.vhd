----------------------------------------------------------------------------------
--
-- Prova Finale (Progetto di Reti Logiche)
-- Prof. Fabio Salice - Anno 2021/2022
--
-- Pierluigi Negro (Codice Persona 10670080 Matricola 933774)
-- Marco Mole' (Codice Persona 10676087 Matricola 932376)
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
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
        IDLE,                   -- Idling. On start signal: initializes all
        WAIT_WORD_NUMBER,       -- Waiting for the memory to load the number of words to consider
        SET_WORD_NUMBER,        -- Registering the number of word to consider
        COMPARE_WORD_COUNT,     -- Comparing the number of words already considered to the number of words to consider
        WAIT_BUFFER_IN,         -- Waiting for the memory to load the current word to consider
        SET_BUFFER_IN,          -- Registering the current word to consider
        COMPUTE,                -- Calculating the outputs of the FSM considering a single bit input at a time
        WRITE_IN_BUFFER,        -- Storing the outputs computed in buffer_out, to be then copied into memory 
        COMPARE_BIT_COUNT,      -- Checking if buffer_out is ready to be copied into memory
        WRITE_MEMORY,           -- Changes memory enablers to 0, checks for loop conditions
        DONE                    -- Waiting for i_start to be put to '0'
    );

    type convolution_type is (S0, S1, S2, S3);
    
    signal curr_state : state_type;
    signal word_counter : integer range 0 to 255;       -- Keeps track of how many words we considered
    signal word_number : integer range 0 to 255;        -- Stores the number of words to consider
    signal buffer_out : std_logic_vector(7 downto 0);   -- Stores the partial results of the FSM computation and is eventually copied to memory
    signal buffer_in : std_logic_vector(7 downto 0);    -- Stores the current considered word
    signal buffer_index : integer range 0 to 7;         -- Acts as an array index for the single bit to be considered in buffer_in
    signal convolution_state : convolution_type;        -- Saves the current state of the convolution computation
    signal p1k : std_logic;                             -- First output of the convolution computation
    signal p2k : std_logic;                             -- Second output of the convolution computation
    signal Uk : std_logic;                              -- Input for the convolution computation

    
begin
    FINATE_STATE_MACHINE: process(i_clk, i_rst)
    begin
        -- Takes into account the asynchronous behaviour of i_rst
        if (i_rst = '1') then
            curr_state <= IDLE;
            o_en <= '0';
            o_we <= '0';

        elsif rising_edge(i_clk) then
            case curr_state is
                
                when IDLE =>
                    if(i_start = '1') then
                        word_counter <= 0;
                        o_en <= '1';
                        o_we <= '0';
                        o_done <= '0';
                        o_address <= (others => '0');
                        buffer_index <= 7;
                        convolution_state <= S0;
                        curr_state <= WAIT_WORD_NUMBER;
                    end if ;
                
                when WAIT_WORD_NUMBER =>
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
                        curr_state <= WAIT_BUFFER_IN;

                    else
                        o_done <= '1';
                        curr_state <= DONE;
                        
                    end if;
                
                when WAIT_BUFFER_IN =>
                  curr_state <= SET_BUFFER_IN;
                
                when SET_BUFFER_IN =>
                    buffer_in <= i_data;
                    o_en <= '0';
                    Uk <= i_data(7);
                    curr_state <= COMPUTE;

                when COMPUTE =>                    
                    curr_state <= WRITE_IN_BUFFER;

                when WRITE_IN_BUFFER =>
                    -- We have to consider buffer index mod 4:
                    -- indexes from 7 to 4 will generate an output word, indexes from 3 to 0 will generate a second output word
                    -- We also have to place p1k always before p2k in the output word to create the correct output
                    if(buffer_index > 3) then
                        buffer_out(buffer_index * 2 - 7) <= p1k;
                        buffer_out(buffer_index * 2 - 8) <= p2k;                    
                    else
                        buffer_out(buffer_index * 2 + 1) <= p1k;
                        buffer_out(buffer_index * 2) <= p2k;
                    end if;

                    -- buffer_index is to be considered an "array index", going from 7 -> 0 then back to 7 to fully parse an input word
                    if(buffer_index = 0) then
                        buffer_index <= 7;
                    else
                        buffer_index <= buffer_index - 1;
                    end if;

                    curr_state <= COMPARE_BIT_COUNT;

                when COMPARE_BIT_COUNT =>
                    -- If buffer_index is at the beginning or in the middle of a word: we just filled buffer_out, which is to be written in memory
                    if(buffer_index = 7 or buffer_index = 3) then                        
                        o_we <= '1';
                        o_en <= '1';
                        o_data <= buffer_out;
                        
                        -- Every input word creates two output words and word_counter only counts input words ->
                        -- we have to double word_counter and offset it so that the first output word is at address = 1000 and the next outputs follow that address
                        if(buffer_index = 3) then
                            -- buffer_index = 3 -> we finished computing the first half of the input word, we have a full output word
                            o_address <= std_logic_vector(to_unsigned(word_counter * 2 + 998, 16));
                            Uk <= buffer_in(3);
                        else
                            -- buffer_index = 7 -> we finished computing the second half of the input word, we have the second full output word
                            o_address <= std_logic_vector(to_unsigned(word_counter * 2 + 999, 16));
                        end if;

                        curr_state <= WRITE_MEMORY;

                    else
                        Uk <= buffer_in(buffer_index);
                        curr_state <= COMPUTE;
                    end if;
                

                when WRITE_MEMORY =>
                    o_we <= '0';
                    o_en <= '0';
                    if(buffer_index = 7) then
                        -- buffer_index = 7 -> we finished computing a full input word
                        curr_state <= COMPARE_WORD_COUNT;
                    else
                        curr_state <= COMPUTE;
                    end if;

                when DONE =>
                    if(i_start = '0') then
                        o_done <= '0';
                        curr_state <= IDLE;
                    end if;
                    
                when others =>
                
                end case;
        end if;
    end process;

    CODIFICATORE: process(i_clk, curr_state, Uk, convolution_state)
    begin
        if (rising_edge(i_clk) AND curr_state = COMPUTE) then
            case( convolution_state ) is
                when S0 =>
                    if(Uk = '0') then
                        convolution_state <= S0;
                        p1k <= '0';
                        p2k <= '0';
                    elsif (Uk = '1') then
                        convolution_state <= S2;
                        p1k <= '1';
                        p2k <= '1';                            
                    end if;
                when S1 =>
                    if(Uk = '0') then
                        convolution_state <= S0;
                        p1k <= '1';
                        p2k <= '1';
                    elsif (Uk = '1') then
                        convolution_state <= S2;
                        p1k <= '0';
                        p2k <= '0';                            
                    end if;
                when S2 =>
                    if(Uk = '0') then
                        convolution_state <= S1;
                        p1k <= '0';
                        p2k <= '1';
                    elsif (Uk = '1') then
                        convolution_state <= S3;
                        p1k <= '1';
                        p2k <= '0';                            
                    end if;
                when S3 =>
                    if(Uk = '0') then
                        convolution_state <= S1;
                        p1k <= '1';
                        p2k <= '0';
                    elsif (Uk = '1') then
                        convolution_state <= S3;
                        p1k <= '0';
                        p2k <= '1';                            
                    end if;                    
            end case ;
        end if;
    end process;
end Behavioral;
