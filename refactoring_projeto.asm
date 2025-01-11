.data
# Buffer de nome e leitura de arquivo
filename: .space 128              # Espaço para o nome do arquivo
buffer:   .space 1024             # Buffer para leitura do arquivo

labels_space: .space 128
hex_chars: .asciiz "0123456789ABCDEF"
hex_convert_buffer: .space 16

nome_arquivo: .asciiz "data.mif"

data_mif_linha: .space 22
dado_buffer: .space 16
data_mif_buffer: .space 512

# Seção atual (.data ou .text)
# Não identificada -> 0
# .data -> 1
# .text -> 2

# $s0 tem o endereço da memória atual
current_section: .byte 0

# Lista de instruções válidas
instructions: .asciiz "add\0sub\0and\0or\0xor\0nor\0slt\0lw\0sw\0beq\0bne\0addi\0andi\0ori\0xori\0"

.text
.globl main
main:
    la $s3, labels_space
    jal inicia_data_mif
    # Solicita o nome do arquivo ao usuário
    jal input_routine
    # Inicia a leitura do arquivo e aloca no buffer
    jal read_file
    
    # Inicia $a0 com o buffer da leitura do arquivo 
    la $a0, buffer 
    jal process_lines


input_routine:                        # Rotina para receber o nome do arquivo

    _print_input_mensage:

        li $v0, 4                     # syscall para imprimir string
        la $a0, prompt_entrada	      # prompt_entrada
        syscall

    _input_nome_arquivo:

        li $v0, 8                     # syscall para leitura de string
        la $a0, filename
        li $a1, 100                   # tamanho máximo da string
        syscall

        # Remove o caractere de nova linha (\n) do final da string
        # remove_newline($a0), um strip
        _remove_newline:
            _remove_newline_loop:
                # loop para remover o caractere de \n
                lb $t0, 0($a0)
                beq $t0, '\n', _found_newline
                beq $t0, 0, _found_newline
                addi $a0, $a0, 1
                j _remove_newline_loop
            _found_newline:
                sb $zero, 0($a0)
    jr $ra # Volta a MAIN

read_file:

    _open_file:
        # Abre o arquivo para leitura
        li $v0, 13                    # syscall para abrir arquivo
        la $a0, filename
        li $a1, 0                     # modo de leitura (0 = read)
        li $a2, 0                     # flags (0 = padrão)
        syscall
        move $s0, $v0                 # file descriptor
        bltz $v0, _erro_abrir_arquivo
        add $s0, $v0, $zero
        
        # Lê e analisa o conteúdo do arquivo
    _read_to_buffer:
        li $v0, 14                    # syscall para ler arquivo
        move $a0, $s0                 # file descriptor
        la $a1, buffer
        li $a2, 1024                  # tamanho do buffer
        syscall
        # Coloca em $v0 -> -1 se o read não deu certo
        bltz $v0, _erro_abrir_arquivo # se retornar -1, fim da leitura
        jr $ra # volta a main

    _erro_abrir_arquivo:
        li $v0, 4
        la $a0, erro_arquivo # print que deu erro em abrir
        syscall
        j close_file # fecha o arquivo e encerra o programa
    
close_file:
    # Fecha o arquivo
    li $v0, 16                    # syscall para fechar arquivo
    move $a0, $s0                 # file descriptor
    syscall

    # Finaliza o programa
    li $v0, 10                    # syscall para encerrar programa
    syscall

process_lines: # Recebe o ponteiro do buffer em $a0

    move $s0, $a0  # mantém o ponteiro do buffer em $s0

    lb $t0, 0($s0) # carrega $t0 com o byte do ponteiro 
    
    _switch_case:
        beqz $t0, fim_do_arquivo
        beq $t0, '\0', fim_do_arquivo
        beq $t0, '#', _skip_line       # Ignora linhas de comentário
        beq $t0, '\n', _next_line      # Ignora linhas em branco
        beq $t0, '.', identifica_parte # Identifica se é .data ou .text
        beq $t0, ' ', _next_byte       # Ignora ' ', menos os necessários
        beq $t0, ':', identifica_label     # Identifica label
        
        # Isola a instrução
        jal isolate_instruction

        # Identifica o tipo de instrução e analisa campos
        jal analyze_instruction

        # Gera o valor hexadecimal e escreve no arquivo
        jal generate_hex
        jal write_hex_file
        j _next_byte
    _next_line:
        
        addi $s1, $s1, 1

    _next_byte:
        
        addi $a0, $a0, 1
        j process_lines

    _skip_line:
        # Pula até o final da linha de comentário
        lb $t1, 0($t0)
        beq $t1, '\n', _next_line
        addi $t0, $t0, 1
        j _skip_line

invalid_instruction:
    # Lança exceção de instrução inexistente e descarta arquivo
    li $v0, 4                     # syscall para imprimir string
    la $a0, invalid_instruction_error # Printa "Invalid instruction detected. Exiting."
    syscall


# Função para isolar a instrução da linha
isolate_instruction:
    # Implementar a lógica para isolar a instrução
    jr $ra

# Função para validar a instrução
validate_instruction: # validate_instruction($a0 [endereço das instruções])
    # Implementar a lógica para validar a instrução
    
    jr $ra

# Função para analisar a instrução e seus campos
analyze_instruction:
    # Implementar a lógica para analisar os campos da instrução
    jr $ra

# Função para gerar o valor hexadecimal da instrução
generate_hex:
    # Implementar a lógica para gerar o valor hexadecimal
    jr $ra

# Função para escrever o valor hexadecimal no arquivo
write_hex_file:
    # Implementar a lógica para escrever no arquivo
    jr $ra

# Erro é acionado ao não conseguir abrir o arquivo

identifica_parte:     
    
    move $a0, $s0 # carrega $a0 com o byte do ponteiro

    # Compara com .data
    la $a1, _data_token # testa se corresponde à parte .data
    li $a2, 5           

    # compara_str(addr1, addr2, compare_len)
    jal compara_str 

    beq $v0, 1, _data_parte
    
    # Compara com .text
    la $a1, _text_token # testa se corresponde à parte .text
    li $a2, 5           

    # compara_str(addr1, addr2, compare_len)
    jal compara_str

    beq $v0, 1, _text_parte

    j _parte_nao_identificada # se não for nenhuma das duas -> parte não identificada

    _data_parte:
        # Passou na verificação, move ao $a0 para continuar lendo o arquivo
        
        lb $t0, 6($a0)
        bne $t0, '\n', invalid_instruction
        
        la $t2, current_section
        addi $t3, $zero, 1 # determina e atualiza a atual seção de código -> seção de dado
        sb $t3, 0($t2)
        
        # inicia a posição da memória da parte de data
        add $s1, $zero, $zero

        addi $a0, $a0, 6 # vai para a próxima linha do código

        j process_lines # volta ao process_lines com o $a0 já alterado

    _text_parte:
        # Passou na verificação, move ao $a0 para continuar lendo o arquivo

	lb $t0, 1($a0)
        bne $t0, '\n', invalid_instruction

        la $t2, current_section
        addi $t3, $zero, 2 # determina e atualiza a atual seção de código -> seção de text
        sb $t3, 0($t2)
        
        # inicia a posição da memória da parte de data
        add $s1, $zero, $zero

        addi $a0, $a0, 6 # vai para a próxima linha do código

        j process_lines # volta ao process_lines com o $a0 já alterado

    _parte_nao_identificada:
        # Possibilidade de tipo de dado
        # SE E SOMENTE SE -> current_section == 1

        la $t0, current_section
        lb $t1, 0($t0)
        bne $t1, 1, invalid_instruction
        
        _verifica_word:
            # Verifica se há ".word "
            la $a1, _word_token # testa se corresponde à parte .data
            li $a2, 5           

            # compara_str(addr1($a0), addr2($a1), compare_len($a2))
            jal compara_str 

            beqz $v0, _verifica_asciiz

            addi $a0, $a0, 5 # vai para a próxima parte do código, pós '.word '

            move $t0, $a0 # copia em $t0 o ponteiro do buffer atual 
            
            add $t2, $zero, $zero # inicia o contador cont = 0
            _rotina_word:
            # verifica byte a byte se tem dado ou ' ' ou ',' ou '\n'
                addi $t0, $t0, 1
                
                lb $t1, 0($t0)
                
                beq $t1, '\r', _rotina_word
                beq $t1, ' ', _rotina_word # volta
                beq $t1, ',', _rotina_virgula_word_token #
                beq $t1, '\n', _rotina_next_line_word
                beqz $t1, _rotina_next_line_word
                
                addi $sp, $sp, -1
                sb $t1, 0($sp)
                addi $t2, $t2, 1

                j _rotina_word

                _rotina_virgula_word_token:
                    # se for virgula, termina a leitura do dado atual
                    # além disso, aloca para o buffer de linha
                    move $s0, $t0 # mantém o ponteiro do buffer

                    
                    move $a0, $sp
                    add $sp, $sp, $t2  # libera a pilha

                    jal ascii_to_decimal

                    move $a0, $v0 # recebe o valor em decimal do dado
                    la $a1, dado_buffer # mantém em dado_buffer
                    jal decimal_to_hex_ascii

                    move $a0, $s1
                    la $a1, data_mif_linha
                    jal decimal_to_hex_ascii # data_mif_linha já vai ter o endereço de memória
                    
                    li $t1, ' '
                    sb $t1, ($t0)
                    addi $t0, $t0, 1

                    li $t1, ':'
                    sb $t1, ($t0)
                    addi $t0, $t0, 1
                    
                    li $t1, ' '
                    sb $t1, ($t0)
                    addi $t0, $t0, 1
                    
                    la $a0, dado_buffer
                    move $a1, $t0 # endereço do buffer data_mif_linha atual
                    li $a2, 8
                    jal aloca_str 

                    move $t0, $a1

                    li $t1, ' '
                    sb $t1, ($t0)
                    addi $t0, $t0, 1

                    li $t1, ';'
                    sb $t1, ($t0)
                    addi $t0, $t0, 1

                    li $t1, '\n'
                    sb $t1, ($t0)
                    addi $t0, $t0, 1

                    la $a0, data_mif_linha
                    move $a1, $s4
                    li $a2, 22
                    jal aloca_str

                    move $s4, $a1 # aponta para o fim da última linha escrita

                    addi $s1, $s1, 1
                    move $t0, $s0 # volta para $t0 o ponteiro do buffer
                    
                    j _rotina_word

                _rotina_next_line_word:
                    # se for next line, termina a leitura do dado atual e continua o process lines
                    # além disso, aloca para o buffer de linha
                    move $s0, $t0 # mantém o ponteiro do buffer

                    move $a0, $sp
                    add $sp, $sp, $t2  # libera a pilha

                    jal ascii_to_decimal

                    move $a0, $v0 # recebe o valor em decimal do dado
                    la $a1, dado_buffer # mantém em dado_buffer
                    jal decimal_to_hex_ascii

                    move $a0, $s1
                    la $a1, data_mif_linha
                    jal decimal_to_hex_ascii # data_mif_linha já vai ter o endereço de memória
                    
                    li $t1, ' '
                    sb $t1, ($t0)
                    addi $t0, $t0, 1

                    li $t1, ':'
                    sb $t1, ($t0)
                    addi $t0, $t0, 1
                    
                    li $t1, ' '
                    sb $t1, ($t0)
                    addi $t0, $t0, 1
                    
                    la $a0, dado_buffer
                    move $a1, $t0 # endereço do buffer data_mif_linha atual
                    li $a2, 8
                    jal aloca_str 

                    addi $s1, $s1, 1
                    move $t0, $a1

                    li $t1, ' '
                    sb $t1, ($t0)
                    addi $t0, $t0, 1

                    li $t1, ';'
                    sb $t1, ($t0)
                    addi $t0, $t0, 1

                    li $t1, '\n'
                    sb $t1, ($t0)
                    addi $t0, $t0, 1
                    
                    la $a0, data_mif_linha
                    move $a1, $s4
                    li $a2, 22
                    jal aloca_str

                    move $s4, $a1 # aponta para o fim da última linha escrita

                    move $t0, $s0 # volta para $t0 o ponteiro do buffer
                    
                    addi $t0, $t0, 1
                    # anda com o ponteiro e volta a rotina de processamento de linha
                    
                    move $a0, $t0
                    j process_lines
                
        #_asciiz_token: .asciiz ".asciiz"
        _verifica_asciiz:
    # ainda não
            la $t2, _asciiz_token
            lb $t3, 1($t2)
            j process_lines
        
        
        #_byte_token: .asciiz ".byte"
        #_ascii_token: .asciiz ".ascii"
        #_half_token: .asciiz ".half"
        #_space_token: .asciiz ".space"

identifica_label:
    addi $sp, $sp, -4 # guarda o ponteiro do buffer na pilha
    sw $a0, 0($sp)

    move $t0, $a0
    # $s1 contém o número na memória correspondente a linha
    add $t2, $zero, $zero # inicia o contador
    _loop_identifica_label:
        addi $t0, $t0, -1
        lb $t1, ($t0)
        beq $t1, '\n', _fim_identifica_label # verifica se é o fim da label
        addi $sp, $sp, -1
        sb $t1, ($sp) # guarda o nome da label na pilha
        addi $t2, $t2, 1 #incrementa o contador

    _fim_identifica_label:
        # $s3 aponta para o fim de Labels_space
        _aloca_nome:
                beqz $t2, _fim_loop_aloca_nome

                lb $t0, ($sp)
                sb $t0, ($s3)
                addi $sp, $sp, 1
                addi $s3, $s3, 1
                addi $t2, $t2, -1 # decrementa o contador
            _fim_loop_aloca_nome:
                li $t0, ':'
                addi $s3, $s3, 1
                sb $t0, ($s3) # LABEL:
                addi $s3, $s3, 1
                la $a1, hex_convert_buffer
                add $a0, $s1, $zero
                jal decimal_to_hex_ascii

                la $a0, hex_convert_buffer
                move $a1, $s3
                li $a2, 8
                jal aloca_str
                move $s3, $a1 # Aponta para o fim da label
                addi $s3, $s3, 1 # aponta para o byte imediato depois do fim da label
    _fim_label:
        lw $a0, 0($sp)
        addi $sp, $sp, 4 # resgata o ponteiro do buffer da pilha
        addi $a0, $a0, 1
        j process_lines





############################################################
# função auxiliar compara strings
# função auxiliar conversão str para decimal
# função auxiliar conversão decimal para str de hexa
############################################################

compara_str:
    move $t0, $a0 # mantenho o $a0 sem alterar
    _loop_compara_str:
        beqz $a2, _fim_igual_compara_str	# while n:
        lb $t4, 0($t0)				# compara '' com ''
        lb $t5, 0($a1)
        bne $t4, $t5, _fim_desigual_compara_str # se não for igual, já termina
        addi $t0, $t0, 1
        addi $a1, $a1, 1
        addi $a2, $a2, -1 # se for igual continua
        j _loop_compara_str

        _fim_desigual_compara_str:
            add $v0, $zero, $zero # false
            jr $ra
        _fim_igual_compara_str:
            addi $v0, $zero, 1 # true
            jr $ra

ascii_to_decimal:
    # Recebe o endereço da string em $a0
    add $v0, $zero, $zero
    move $t0, $a0          # ponteiro da string

    _convert_loop:

        lb $t1, 0($t0) # carrega byte
        beqz $t1, _convert_end # se zero vai pro final

        subi $t1, $t1, 48 # converte o ASCII para número           
        
        li $t2, 10
        mult $v0, $t2 # multiplica por 10
        mflo $v0
        
        add $v0, $v0, $t1 # adiciona novo dígito
        addi $t0, $t0, 1 # e continua o loop
        j _convert_loop
        
    _convert_end:
        jr $ra

decimal_to_hex_ascii:
    # Recebe em $a0 o número decimal e em $a1 o buffer para a str hexadecimal
    
    move $t0, $a1 # ponteiro buffer
    li $t1, 8 # contador de dígitos
    move $t2, $a0 # valor para converter
    
    _hex_loop:
        beqz $t1, _hex_end      # se contador zero, termina
        
        # Pega os 4 bits mais significativos
        andi $t3, $t2, 0xF0000000  # usa uma máscara de and para os mais significativos
        srl $t3, $t3, 28 # e move para posição menos significativa
        
        # Converte para caractere ASCII
        la $t4, hex_chars
        add $t4, $t4, $t3
        lb $t4, 0($t4) # carrega caractere hex
        
        # Armazena no buffer
        sb $t4, ($t0)
        
        sll $t2, $t2, 4 # deloca para a esquerda ximos 4 bits
        addi $t0, $t0, 1 # e parte para a próxima posição do buffer
        addi $t1, $t1, -1 # decrementa contador
        j _hex_loop
    
    _hex_end:
        jr $ra

aloca_str:
    # recebe em $a0 a label que vai ser alocada
    # rebebe em $a1 o destino da str
    # e em $a2 o tamanho da string a ser alocada
    
    beqz $a2, _fim_aloca_str
    addi $a2, $a2, -1
    lb $t0, ($a0)
    sb $t0, ($a1)
    addi $a0, $a0, 1
    addi $a1, $a1, 1
    j aloca_str
    _fim_aloca_str:
        jr $ra

inicia_data_mif:
    addi $sp, $sp, -4

    sw $ra, 0($sp)
    la $a0, data_mif_cabecalho
    la $a1, data_mif_buffer
    li $a2, 81
    jal aloca_str


    add $s4, $zero, $a1
    lw $ra, 0($sp)
    addi $sp, $sp, 4

    jr $ra

fim_do_arquivo:
    la $a0, rodape_mif
    move $a1, $s4
    li $a2, 5
    jal aloca_str

    li   $v0, 13                 # Cria um novo arquivo
    la   $a0, nome_arquivo         
    li   $a1, 1                 
    li   $a2, 0x644            
    syscall                     

    move $s0, $v0              
    
    # Checa se houve erro 
    bltz $s0, open_error       # If negative, there was an error
    
    # Write to the file
    li   $v0, 15               # System call 15: write to file
    move $a0, $s0              # File descriptor
    la   $a1, data_mif_buffer         # Address of message
    li   $a2, 512                # Length of message (4 chars)
    syscall
    
    # Close the file
    li   $v0, 16               # System call 16: close file
    move $a0, $s0              # File descriptor to close
    syscall
    
    # Exit program
    j exit_program

    open_error:
        # Print error message
        li   $v0, 4                # System call 4: print string
        la   $a0, erro_arquivo        # Load error message
        syscall

    exit_program:
        li   $v0, 10               # System call 10: exit
        syscall

.data
# Tokens de directivas do Parser

_data_token: .asciiz ".data"
_text_token: .asciiz ".text"
_word_token: .asciiz ".word "
_asciiz_token: .asciiz ".asciiz "
_byte_token: .asciiz ".byte "
_ascii_token: .asciiz ".ascii "
_half_token: .asciiz ".half "
_space_token: .asciiz ".space "

# Mensagens

prompt_entrada: .asciiz "Digite o nome do arquivo (.asm): "
erro_arquivo: .asciiz "Erro ao abrir o arquivo\n"
sucesso_arquivo: .asciiz "Arquivo aberto com sucesso\n"
invalid_instruction_error: .asciiz "Invalid instruction detected. Exiting."

# MIF

data_mif_cabecalho: .asciiz "DEPTH = 16384;\nWIDTH = 32;\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\nCONTENT\nBEGIN\n\n"
text_mif_cabecalho: .asciiz "DEPTH = 4096;\nWIDTH = 32;\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\nCONTENT\nBEGIN\n\n"
rodape_mif: .asciiz "\nEND;\n"
