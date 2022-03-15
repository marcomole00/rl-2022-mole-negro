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
        WAIT_WORD_NUMBER,
        SET_WORD_NUMBER,
        COMPARE_WORD_COUNT,
        WAIT_BUFFER_IN,
        SET_BUFFER_IN,
        COMPUTE,
        WRITE_IN_BUFFER,
        COMPARE_BIT_COUNT,
        WRITE_MEMORY,
        COMPARE_HALF_WORD,
        DONE
    );

    type convolution_type is (S0, S1, S2, S3);
    
    signal curr_state : state_type;
    signal word_counter : integer range 0 to 255;
    signal word_number : integer range 0 to 255;
    signal buffer_out : std_logic_vector(7 downto 0);
    signal buffer_in : std_logic_vector(7 downto 0);
    signal buffer_index : integer range 0 to 7;
    signal convolution_state : convolution_type;
    signal p1k : std_logic;
    signal p2k : std_logic;
    --signal half_word : integer range 0 to 1;
    signal Uk : std_logic;

    
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
                        --o_en <= '1'; --necessario se no non legge in tempo la memeoria
                        curr_state <= INIT;
                    end if;
                
                when INIT =>
                    word_counter <= 0;
                    o_en <= '1';
                    o_we <= '0';
                    o_done <= '0';
                    o_address <= (others => '0');
                    buffer_index <= 7;
                    convolution_state <= S0;
                    curr_state <= WAIT_WORD_NUMBER;
                
                when WAIT_WORD_NUMBER =>
                    -- dobbiamo aspettare un giro di clock in più per la lettura efficace
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
                    curr_state <= WRITE_IN_BUFFER;

                when WRITE_IN_BUFFER =>
                    if(buffer_index > 3) then
                        buffer_out(buffer_index * 2 - 7) <= p1k;
                        buffer_out(buffer_index * 2 - 8) <= p2k;
                    
                    else
                        buffer_out(buffer_index * 2 + 1) <= p1k;
                        buffer_out(buffer_index * 2) <= p2k;

                    end if;

                    if(buffer_index = 0) then
                        buffer_index <= 7;
                    else
                        buffer_index <= buffer_index - 1;
                    end if;

                    curr_state <= COMPARE_BIT_COUNT;

                when COMPARE_BIT_COUNT =>
                    if(buffer_index = 7 or buffer_index = 3) then
                        
                        o_we <= '1';
                        o_en <= '1';
                        o_data <= buffer_out;
                        --buffer_out <= (others => '0');
                        
                        if(buffer_index = 3) then
                            o_address <= std_logic_vector(to_unsigned(word_counter * 2 + 998, 16));
                        else
                            o_address <= std_logic_vector(to_unsigned(word_counter * 2 + 999, 16));
                            Uk <= buffer_in(buffer_index);
                        end if;

                        curr_state <= WRITE_MEMORY;

                    else
                        Uk <= buffer_in(buffer_index);
                        curr_state <= COMPUTE;
                    end if;
                
                when WRITE_MEMORY =>
                    -- non so se è giusto 
                    -- potrebbe essere mergiato con COMPARE_HALF_WORD
                    
                    o_we <= '0';
                    o_en <= '0';
                    curr_state <= COMPARE_HALF_WORD;

                when COMPARE_HALF_WORD =>
                    if(buffer_index = 7) then 
                        curr_state <= COMPARE_WORD_COUNT;
                    else
                        Uk <= buffer_in(buffer_index);
                        curr_state <= COMPUTE;
                    end if;

                when DONE =>
                    if(i_start = '0') then
                        o_done <= '0';
                        curr_state <= IDLE;
                    end if;
                end case;
        end if;
    end process;
end Behavioral;
