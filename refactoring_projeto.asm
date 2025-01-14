.data
# Buffer de nome e leitura de arquivo
filename: .space 128              # Espaço para o nome do arquivo
buffer:   .space 1024             # Buffer para leitura do arquivo

buffer_nome_label: .space 64
labels_space: .space 256 # Segue o seguinte modelo LABEL 0\:00000000 0\LABEL2 0\:000000001
hex_chars: .asciiz "0123456789ABCDEF"
hex_convert_buffer: .space 16

nome_arquivo_data: .asciiz "data.mif"
nome_arquivo_text: .asciiz "text.mif"

# Buffer para as instruções
opcode_buffer: .space 8
rs_buffer: .space 8
rt_buffer: .space 8
rd_buffer: .space 8
shamt_buffer: .space 8
funct_buffer: .space 8
imm_buffer: .space 16
addr_buffer: .space 32
instruction_buffer: .space 8

data_mif_linha: .space 22
dado_buffer: .space 16
data_mif_buffer: .space 512 # s4 aponta para o fim de data_mif_buffer

text_mif_linha: .space 22
text_mif_buffer: .space 512 # s5 aponta para o fim de text_mif_buffer

# Seção atual (.data ou .text)
# Não identificada -> 0
# .data -> 1
# .text -> 2

# $s0 tem o endereço da memória atual
current_section: .byte 0

.text
.globl main
main:
    # Inicialização dos buffers
    la $s3, labels_space
    jal inicia_data_mif # $s4 aponta para o fim do data_mif_buffer
    jal inicia_text_mif # $s5 aponta para o fim do text_mif_buffer

    # Solicita o nome do arquivo ao usuário
    jal input_routine
    # Inicia a leitura do arquivo e aloca no buffer
    jal read_file
    
    # Inicia $a0 com o buffer da leitura do arquivo 
    la $a0, buffer 
    jal process_lines

    # data já gerado

    # Inicia $a0 com o buffer da parte de text do arquivo
    add $s1, $zero, $zero
    move $a0, $s6
    jal process_instructions

    j fim_do_arquivo


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
    addi $sp, $sp, -4 # preserva a volta para main
    sw $ra, 0($sp)
    process_lines_switch_case:

        move $s0, $a0  # mantém o ponteiro do buffer em $s0
        lb $t0, 0($s0) # carrega $t0 com o byte do ponteiro

        beqz $t0, _fim_process_lines
        beq $t0, '#', _skip_line       # Ignora linhas de comentário
        beq $t0, '\n', _next_line      # Ignora linhas em branco
        beq $t0, '.', identifica_parte # Identifica se é .data ou .text
        beq $t0, ' ', _next_byte       # Ignora ' ', menos os necessários
        beq $t0, ':', identifica_label     # Identifica label
        
        la $a1, _xori_token
        li $a2, 5
        jal compara_str
        beq $v0, 1, _xori_encontrado

        j _next_byte

    _next_line:
        lb $t0, -2($s0) # verifica se é uma linha em branco
        beq $t0, '\n', _next_byte
        addi $s1, $s1, 1
    _next_byte:
        addi $a0, $a0, 1
        j process_lines_switch_case

    _skip_line:
        # Pula até o final da linha de comentário
        lb $t1, 0($a0)
        beq $t1, '\n', _next_byte
        addi $a0, $a0, 1
        j _skip_line

    _xori_encontrado:
        addi $s1, $s1, 2
        addi $a0, $a0, 1
        j process_lines_switch_case

    _fim_process_lines:
        lw $ra, 0($sp)
        addi $sp, $sp, 4 # volta para a main
        
        jr $ra

process_instructions:
    addi $sp, $sp, -4 # preserva a volta para main
    sw $ra, 0($sp)
    
    process_instructions_switch_case:
        move $s0, $a0  # mantém o ponteiro do buffer em $s0

        lb $t0, 0($s0) # carrega $t0 com o byte do ponteiro

        beqz $t0, _fim_process_instructions
        beq $t0, '#', _skip_line_instructions       # Ignora linhas de comentário
        beq $t0, '\n', _next_line_instructions      # Ignora linhas em branco
        beq $t0, ' ', _next_byte_instructions       # Ignora ' ', menos os necessários
        
        # TIPO R

        la $a1, _add_token
        li $s6, 4 # tamanho do token
        move $a2, $s6
        jal compara_str
        beq $v0, 1, _instrucao_add

            _instrucao_add:
                add $a0, $a0, $s6 # anda o tamanho de add
                la $t1, opcode_buffer
                sb $zero, 0($t1) # salva o opcode
                li $t0, 32
                la $t1, funct_buffer
                sb $t0, 0($t1) # salva o funct
                la $t1, shamt_buffer 
                sb $zero, 0($t1) # salva o shamt

                j procura_argumentos_tipo_r


            _instrucao_j:
            _instrucao_jr:
            _instrucao_jal:
            _instrucao_jalr:
            _instrucao_xori:

        j _next_byte_instructions

    _next_line_instructions:
        lb $t0, -2($s0) # verifica se é uma linha em branco
        beq $t0, '\n', _next_byte_instructions
    _next_byte_instructions:
        addi $a0, $a0, 1
        j process_instructions_switch_case

    _skip_line_instructions:
        # Pula até o final da linha de comentário
        lb $t1, 0($a0)
        beq $t1, '\n', _next_byte_instructions
        addi $a0, $a0, 1
        j _skip_line

    _fim_process_instructions:
        lw $ra, 0($sp)
        addi $sp, $sp, 4 # volta para a main
        jr $ra

procura_argumentos_tipo_r:
    # recebe em $a0 o ponteiro para uma instrução
    move $t0, $a0

    add $t6, $zero, $zero # inicia o contador de argumentos
    _loop_procura_args_tipo_r:
        lb $t1, 0($t0)
        move $s0, $t0 # mantém o ponteiro do arg atual
        
        beqz $t1, _next_line_tipo_r
        beq $t1, ' ', _next_byte_tipo_r
        beq $t1, '\n', _next_line_tipo_r
        beq $t1, ',', _next_arg_tipo_r

        move $a0, $s0
        la $a1, _0_token # token
        li $a2, 2
        jal compara_str # a0 é preservado nas comparações
        add $a0, $zero, $zero # número do argumento $0
        li $a1, 2
        beq $v0, 1, aloca_argumento

        move $a0, $s0
        la $a1, _zero_token
        li $a2, 5 # len("$at")
        jal compara_str # a0 é preservado nas comparações
        add $a0, $zero, $zero
        li $a1, 5 # len("$at")
        beq $v0, 1, aloca_argumento

        move $a0, $s0
        la $a1, _1_token
        li $a2, 2
        jal compara_str # a0 é preservado nas comparações
        li $a0, 1
        li $a1, 2
        beq $v0, 1, aloca_argumento

        move $a0, $s0
        la $a1, _at_token
        li $a2, 3  # len("$at")
        jal compara_str # a0 é preservado nas comparações
        li $a0, 1
        li $a1, 3 # len("$at")
        beq $v0, 1, aloca_argumento

    _next_byte_tipo_r:
        addi $t0, $t0, 1
        j _loop_procura_args_tipo_r

    _next_line_tipo_r:
        # gera linha de código de máquina e depois vai para o fim
        addi $t0, $t0, 1
        move $s0, $t0 # buffer atual do arquivo orginal

        add $t2, $zero, $zero

        la $t1, opcode_buffer
        lb $t3, 0($t1)

        sll $t3, $t3, 26

        addu $t2, $t2, $t3

        la $t1, rs_buffer
        lb $t3, 0($t1)

        sll $t3, $t3, 21
        addu $t2, $t2, $t3

        la $t1, rt_buffer
        lb $t3, 0($t1)

        sll $t3, $t3, 16
        addu $t2, $t2, $t3

        la $t1, rd_buffer
        lb $t3, 0($t1)

        sll $t3, $t3, 11
        addu $t2, $t2, $t3

        la $t1, shamt_buffer
        lb $t3, 0($t1)

        sll $t3, $t3, 6
        addu $t2, $t2, $t3

        la $t1, funct_buffer
        lb $t3, 0($t1)

        addu $t2, $t2, $t3

        # Fecha a instrução com tudo

        move $a0, $t2 # recebe o valor em decimal da instrução
        la $a1, instruction_buffer # mantém em instruction_buffer
        jal decimal_to_hex_ascii

        move $a0, $s1
        la $a1, text_mif_linha
        jal decimal_to_hex_ascii # text_mif_linha já vai ter o endereço de memória
        
        li $t1, ' '
        sb $t1, ($t0)
        addi $t0, $t0, 1

        li $t1, ':'
        sb $t1, ($t0)
        addi $t0, $t0, 1
        
        li $t1, ' '
        sb $t1, ($t0)
        addi $t0, $t0, 1
        
        la $a0, instruction_buffer
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
        
        la $a0, text_mif_linha
        move $a1, $s5
        li $a2, 22
        jal aloca_str

        li $t1, ' '
        sb $t1, ($a1)
        addi $a1, $a1, 1

        move $s5, $a1 # aponta para o último endereço de text_mif
        addi $s1, $s1, 1
        move $a0, $s0
        j process_instructions_switch_case
        

    _next_arg_tipo_r:
        # adiciona no num de args
        addi $t6, $t6, 1
        addi $t0, $t0, 1
        j _loop_procura_args_tipo_r
        

    _fim_procura_args:
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        jr $ra # volta para process_instructions


aloca_argumento:
    # recebe em $a0 o valor do argumento
    # recebe em $a1 o tamanho da str do argumento
    # $s0 tem o ponteiro do arg atual
    beqz $t6, _aloca_rd
    beq $t6, 1, _aloca_rs
    beq $t6, 2, _aloca_rt
    beq $t6, 3, invalid_instruction

    _aloca_rd:
        la $t0, rd_buffer
        sb $a0, 0($t0)
        add $s0, $s0, $a1
        move $t0, $s0
        j _loop_procura_args_tipo_r

    _aloca_rs:
        la $t0, rs_buffer
        sb $a0, 0($t0)
        add $s0, $s0, $a1
        move $t0, $s0
        j _loop_procura_args_tipo_r

    _aloca_rt:
        la $t0, rt_buffer
        sb $a0, 0($t0)
        add $s0, $s0, $a1
        move $t0, $s0
        j _loop_procura_args_tipo_r

invalid_instruction:
    # Lança exceção de instrução inexistente e descarta arquivo
    li $v0, 4                     # syscall para imprimir string
    la $a0, invalid_instruction_error # Printa "Invalid instruction detected. Exiting."
    syscall

    j close_file

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

        addi $a0, $a0, 7 # vai para a próxima linha do código

        j process_lines_switch_case # volta ao process_lines com o $a0 já alterado

    _text_parte:
        # Passou na verificação, move ao $a0 para continuar lendo o arquivo

	    lb $t0, 6($a0)
        bne $t0, '\n', invalid_instruction

        la $t2, current_section
        addi $t3, $zero, 2 # determina e atualiza a atual seção de código -> seção de text
        sb $t3, 0($t2)
        
        # inicia a posição da memória da parte de data
        add $s1, $zero, $zero

        addi $a0, $a0, 7 # vai para a próxima linha do código

        move $s6, $a0

        j process_lines_switch_case # volta ao process_lines com o $a0 já alterado

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

                    addi $sp, $sp, -1
                    sb $zero, 0($sp)

                    move $s0, $t0 # mantém o ponteiro do buffer
                    
                    add $sp, $sp, $t2  # libera a pilha e prepara para leitura
                    move $a0, $sp

                    addi $sp, $sp, 1 # libera finalmente a pilha
                    
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
                    addi $sp, $sp, -1
                    sb $zero, 0($sp)

                    move $s0, $t0 # mantém o ponteiro do buffer
                    
                    add $sp, $sp, $t2  # libera a pilha e prepara para leitura
                    move $a0, $sp
                    addi $sp, $sp, 1 # libera finalmente a pilha

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
                    j process_lines_switch_case
                
        #_asciiz_token: .asciiz ".asciiz"
        _verifica_asciiz:
        # ainda não
            la $t2, _asciiz_token
            lb $t3, 1($t2)
            j process_lines_switch_case
        
        
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
        j _loop_identifica_label

    _fim_identifica_label:
        move $t6, $t2 # mantém o tamanho da label
        la $t1, buffer_nome_label
        _loop_aloca_nome_buffer:
        # carrega a label no buffer para analisar se é repetida
            beqz $t2, _verifica_nome
            lb $t0, ($sp)
            sb $t0, ($t1)
            addi $sp, $sp, 1
            addi $t1, $t1, 1
            addi $t2, $t2, -1 # decrementa o contador
            j _loop_aloca_nome_buffer

        _verifica_nome:
            addi $t1, $t1, 1
            sb $zero, ($t1)
        
            la $a0, buffer_nome_label
            move $a1, $t6
            jal verifica_label
            bgt $v0, -1, erro_label_repetida
            la $t1, buffer_nome_label
        # $s3 aponta para o fim de Labels_space
        _aloca_nome:
            beqz $t6, _fim_loop_aloca_nome
            
            lb $t0, ($t1)
            sb $zero, ($t1) # reseta o buffer de nome
            sb $t0, ($s3)
            addi $t1, $t1, 1
            addi $s3, $s3, 1
            addi $t6, $t6, -1 # decrementa o contador
            j _aloca_nome

            _fim_loop_aloca_nome:
                li $t0, ':'
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
        j process_lines_switch_case

erro_label_repetida:
    li $v0, 4
    la $a0, _erro_label_repetida
    syscall
    j exit_program

############################################################
# função auxiliar compara strings
# função auxiliar conversão str para decimal
# função auxiliar conversão decimal para str de hexa
############################################################

compara_str:
    move $t0, $a0 # mantenho o $a0 sem altera
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
        addi $t0, $t0, -1 # e continua o loop
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
        
        sll $t2, $t2, 4 # desloca para a esquerda ximos 4 bits
        addi $t0, $t0, 1 # e parte para a próxima posição do buffer
        addi $t1, $t1, -1 # decrementa contador
        j _hex_loop
    
    _hex_end:
        jr $ra

ascii_hex_to_decimal:
    # recebe $a0 como endereço da string de Hex  
    # retorna em $v0 o valor em decimal da conversão
    
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $s0, 0($sp)
    
    add $v0, $zero, $zero            # Initialize result
    move $s0, $a0          # Salva o endereço
    
    _ascii_convert_loop:
        lb $t0, ($s0)          
        beqz $t0, _fim         # Verifica se já terminou
        
        add $t1, $zero, $zero              
        
        # Verifica se é um dígito
        li $t1, '0'
        blt $t0, $t1, _invalido
        li $t1, '9'
        ble $t0, $t1, _digito
        
        # Ou se é uma letra
        li $t1, 'A'
        blt $t0, $t1, _invalido
        li $t1, 'F'
        ble $t0, $t1, _letra

        _digito:
            sub $t2, $t0, '0'
            j _continua

        _letra:
            sub $t2, $t0, 'A'
            addi $t2, $t2, 10
            j _continua

        _continua:
            sll $v0, $v0, 4        # move pra esquerda
            add $v0, $v0, $t2      # adiciona o novo dígito
            addi $s0, $s0, 1 # continua a conversão
            j _ascii_convert_loop

        _invalido: # se for um dígito inválido printa mensagem de erro
            li $v0, 4             
            la $a0, _erro_de_conversao
            syscall
            li $v0, -1             
        
    _fim:
        lw $s0, 0($sp)         # desempilha 
        lw $ra, 4($sp)
        addi $sp, $sp, 8
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

inicia_text_mif:
    addi $sp, $sp, -4

    sw $ra, 0($sp)
    la $a0, text_mif_cabecalho
    la $a1, text_mif_buffer
    li $a2, 81
    jal aloca_str


    add $s5, $zero, $a1
    lw $ra, 0($sp)
    addi $sp, $sp, 4

    jr $ra

fim_do_arquivo:

    ##########################################################
    # Monta o arquivo data

    la $a0, rodape_mif
    move $a1, $s4
    li $a2, 5
    jal aloca_str

    li   $v0, 13                 # Cria um novo arquivo
    la   $a0, nome_arquivo_data         
    li   $a1, 1                 
    li   $a2, 0x644            
    syscall                     

    move $s0, $v0              
    
    # Checa se houve erro 
    bltz $s0, create_error       # Se negativo teve erro
    
    # Escreve no arquivo
    li   $v0, 15               
    move $a0, $s0              # File descriptor
    la   $a1, data_mif_buffer  
    li   $a2, 512                # Tamanho da mensagem
    syscall
    
    # Fecha o arquivo
    li   $v0, 16               # Fecha o arquivo
    move $a0, $s0              # File descriptor para fechar
    syscall

    ##########################################################
    # Monta o arquivo text
    la $a0, rodape_mif
    move $a1, $s5
    li $a2, 5
    jal aloca_str

    li   $v0, 13                 # Cria um novo arquivo
    la   $a0, nome_arquivo_text         
    li   $a1, 1                 
    li   $a2, 0x644            
    syscall                     

    move $s0, $v0              
    
    # Checa se houve erro 
    bltz $s0, create_error       # Se negativo teve erro
    
    # Escreve no arquivo
    li   $v0, 15               
    move $a0, $s0              # File descriptor
    la   $a1, text_mif_buffer  
    li   $a2, 512                # Tamanho da mensagem
    syscall
    
    # Fecha o arquivo
    li   $v0, 16               # Fecha o arquivo
    move $a0, $s0              # File descriptor para fechar
    syscall

    
    # Exit program
    j exit_program

    create_error:
        # Print error message
        li   $v0, 4                # System call 4: print string
        la   $a0, erro_criar_arquivo        # Load error message
        syscall

    exit_program:
        li   $v0, 10               # System call 10: exit
        syscall

verifica_label:
    # Recebe em a0 o ponteiro da label
    # Recebe em a1 o tamanho da label
    # Verifica se a label existe e retorna o número da memória
    # Se não existe, retorna -1 em $v0
    addi $a1, $a1, 1 # adiciona mais um para comparar com o fim da label
    move $t6, $a1 # mantém o tamanho da label
    la $a1, labels_space
    
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    _loop_verifica_label:

        move $a2, $t6
        jal compara_str
        bnez $v0, _fim_loop_verifica_label

        _loop_procura_label:
            addi $a1, $a1, 12 # pula o número de endereço da label, visto que ela não é igual a comparada
            lb $t0, ($a1)
            beqz $t0, _fim_loop_verifica_label # se 0 não tem mais label 
            j _loop_verifica_label

    _fim_loop_verifica_label:

        beqz $v0, _label_nao_existe

    _label_existe:
        addi $a1, $a1, 3
        move $a0, $a1
        jal ascii_hex_to_decimal
        j _fim_verifica_label
        
    _label_nao_existe:
        li $v0, -1

    _fim_verifica_label:
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        jr $ra

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
erro_criar_arquivo: .asciiz "Erro ao criar o arquivo\n"
_erro_label_repetida: .asciiz "Erro ao criar label, nome já utilizado\n"
_erro_de_conversao: .asciiz "Erro ao converter hex string para decimal\n"

# MIF

data_mif_cabecalho: .asciiz "DEPTH = 16384;\nWIDTH = 32;\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\nCONTENT\nBEGIN\n\n"
text_mif_cabecalho: .asciiz "DEPTH = 4096;\nWIDTH = 32;\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\nCONTENT\nBEGIN\n\n"
rodape_mif: .asciiz "\nEND;\n"


# Lista de argumentos válidos
_zero_token: .asciiz "$zero"
_0_token: .asciiz "$0"

_at_token: .asciiz "$at"
_1_token: .asciiz "$1"

_v0_token: .asciiz "$v0"
_2_token: .asciiz "$2"

_v1_token: .asciiz "$v1"
_3_token: .asciiz "$3"

_a0_token: .asciiz "$a0"
_4_token: .asciiz "$4"

_a1_token: .asciiz "$a1"
_5_token: .asciiz "$5"

_a2_token: .asciiz "$a2"
_6_token: .asciiz "$6"

_a3_token: .asciiz "$a3"
_7_token: .asciiz "$7"

_t0_token: .asciiz "$t0"
_8_token: .asciiz "$8"

_t1_token: .asciiz "$t1"
_9_token: .asciiz "$9"

_t2_token: .asciiz "$t2"
_10_token: .asciiz "$10"

_t3_token: .asciiz "$t3"
_11_token: .asciiz "$11"

_t4_token: .asciiz "$t4"
_12_token: .asciiz "$12"

_t5_token: .asciiz "$t5"
_13_token: .asciiz "$13"

_t6_token: .asciiz "$t6"
_14_token: .asciiz "$14"

_t7_token: .asciiz "$t7"
_15_token: .asciiz "$15"

_t8_token: .asciiz "$t8"
_24_token: .asciiz "$24"

_t9_token: .asciiz "$t9"
_25_token: .asciiz "$25"

_s0_token: .asciiz "$s0"
_16_token: .asciiz "$16"

_s1_token: .asciiz "$s1"
_17_token: .asciiz "$17"

_s2_token: .asciiz "$s2"
_18_token: .asciiz "$18"

_s3_token: .asciiz "$s3"
_19_token: .asciiz "$19"

_s4_token: .asciiz "$s4"
_20_token: .asciiz "$20"

_s5_token: .asciiz "$s5"
_21_token: .asciiz "$21"

_s6_token: .asciiz "$s6"
_22_token: .asciiz "$22"

_s7_token: .asciiz "$s7"
_23_token: .asciiz "$23"

_ra_token: .asciiz "$ra"
_31_token: .asciiz "$31"

_gp_token: .asciiz "$gp"
_28_token: .asciiz "$28"

_sp_token: .asciiz "$sp"
_29_token: .asciiz "$29"

_fp_token: .asciiz "$fp"
_30_token: .asciiz "$30"

_lo_token: .asciiz "$lo"
_hi_token: .asciiz "$hi"

# Lista de instruções válidas
# TIPO R
_lw_token: .asciiz "lw "
_add_token: .asciiz "add " # pode aceitar imediato também
_sub_token: .asciiz "sub "
_and_token: .asciiz "and "
_or_token: .asciiz "or "
_nor_token: .asciiz "nor "
_xor_token: .asciiz "xor "
_addu_token: .asciiz "addu "
_subu_token: .asciiz "subu "
_sll_token: .asciiz "sll "
_srl_token: .asciiz "srl "
_sllv_token: .asciiz "sllv "
_mult_token: .asciiz "mult "
_div_token: .asciiz "div "
_mfhi_token: .asciiz "mfhi "
_mflo_token: .asciiz "mflo "
_break_token: .asciiz "break" # caso especial
_lwr_token: .asciiz "lwr "
_bnel_token: .asciiz "bnel "
_movz_token: .asciiz "movz "
_multu_token: .asciiz "multu "
_bal_token: .asciiz "bal "
_bgtzl_token: .asciiz "bgtzl "
_msub_token: .asciiz "msub "
_srlv_token: .asciiz "srlv "
_tne_token: .asciiz "tne "
_beq_token: .asciiz "beq "
_bne_token: .asciiz "bne "
_slt_token: .asciiz "slt "
_lui_token: .asciiz "lui "
_sw_token: .asciiz "sw "

# TIPO I
_addi_token: .asciiz "addi "
_andi_token: .asciiz "andi "
_ori_token: .asciiz "ori "
_xori_token: .asciiz "xori "

# TIPO J
_j_token: .asciiz "j "
_jr_token: .asciiz "jr "
_jal_token: .asciiz "jal "
_jalr_token: .asciiz "jalr "
