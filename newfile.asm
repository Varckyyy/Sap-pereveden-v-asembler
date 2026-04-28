asm
section .data
    WIDTH       equ 70
    HEIGHT      equ 25

    clear_screen db  0x1B, '[2J', 0
    cursor_home  db  0x1B, '[H', 0
    reset_color db  0x1B, '[0m', 0
    color_prefix db 0x1B, '[38;2;', 0
    color_mid    db ';', 0
    color_mid2   db ';', 0
    color_suffix db 'm●', 0
    border_hypen db '-', 0
    border_plus  db '+', 0
    pipe_char    db '|', 0
    space_char   db ' ', 0
    hour_label   db ' Час: ', 0
    color_label  db '   |   Цвет шарика: (', 0
    close_paren  db ')', 10, 0
    exit_msg     db ' Используй Ctrl + C для выхода', 10, 0

section .bss
    x resd 1
    y resd 1
    velX resd 1
    velY resd 1
    hour resd 1
    r resd 1
    g resd 1
    b resd 1
    row resd 1
    col resd 1

section .text
    global _start

extern time
extern localtime
extern write
extern usleep
extern exit

; struct tm layout (for localtime result)
; tm_hour is at offset 20 (0x14) in struct tm on Linux x86_64

_start:
    ; Initialize float values
    ; x = WIDTH / 2.0f
    mov dword [x], 0
    mov dword [y], 0
    mov dword [velX], 0
    mov dword [velY], 0

    ; Use xmm registers for float constants
    ; WIDTH / 2.0f = 35.0
    mov eax, WIDTH
    cvtsi2ss xmm0, eax
    movss xmm1, dword [half_float]
    divss xmm0, xmm1
    movss dword [x], xmm0

    ; HEIGHT / 2.0f = 12.5
    mov eax, HEIGHT
    cvtsi2ss xmm0, eax
    movss xmm1, dword [half_float]
    divss xmm0, xmm1
    movss dword [y], xmm0

    ; velX = 1.4f
    movss dword [velX], dword [velX_val]
    ; velY = 0.9f
    movss dword [velY], dword [velY_val]

main_loop:
    ; Get current time_t now = time(NULL)
    xor rdi, rdi
    call time
    mov rdi, rax
    call localtime
    test rax, rax
    jz no_localtime

    ; tm_hour is at offset 20 in struct tm
    movzx eax, byte [rax + 20]
    mov [hour], eax
    jmp got_hour

no_localtime:
    mov dword [hour], 0

got_hour:
    ; Calculate t = hour / 23.0f
    mov eax, [hour]
    cvtsi2ss xmm0, eax
    movss xmm1, dword [twentythree_float]
    divss xmm0, xmm1

    ; Calculate r = 255 + int(t * (220 - 255)) = 255 + int(t * -35)
    movss xmm2, xmm0
    movss xmm3, dword [neg_35_float]
    mulss xmm2, xmm3
    cvtss2si eax, xmm2
    add eax, 255
    mov [r], eax

    ; Calculate g = 255 + int(t * (20 - 255)) = 255 + int(t * -235)
    movss xmm2, xmm0
    movss xmm3, dword [neg_235_float]
    mulss xmm2, xmm3
    cvtss2si eax, xmm2
    add eax, 255
    mov [g], eax

    ; Calculate b = 255 + int(t * (60 - 255)) = 255 + int(t * -195)
    movss xmm2, xmm0
    movss xmm3, dword [neg_195_float]
    mulss xmm2, xmm3
    cvtss2si eax, xmm2
    add eax, 255
    mov [b], eax

    ; Clear screen and move cursor home
    mov rdi, 1          ; stdout
    mov rsi, clear_screen
    mov rdx, 3
    call write

    mov rdi, 1
    mov rsi, cursor_home
    mov rdx, 2
    call write

    ; Print top border: "+" + WIDTH * '-' + "+"
    mov rdi, 1
    mov rsi, border_plus
    mov rdx, 1
    call write

    mov rdi, 1
    mov rsi, border_hypen
    mov rdx, WIDTH
    call write

    mov rdi, 1
    mov rsi, border_plus
    mov rdx, 1
    call write

    ; Print newline
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    call write

    ; Loop rows
    xor ecx, ecx        ; row = 0
row_loop:
    cmp ecx, HEIGHT
    jge after_rows

    ; Print '|'
    mov rdi, 1
    mov rsi, pipe_char
    mov rdx, 1
    call write

    ; Loop cols
    xor edx, edx        ; col = 0
col_loop:
    cmp edx, WIDTH
    jge after_cols

    ; Check if row == (int)y and col == (int)x
    movss xmm0, dword [y]
    cvtss2si esi, xmm0
    cmp esi, ecx
    jne print_space

    movss xmm0, dword [x]
    cvtss2si esi, xmm0
    cmp esi, edx
    jne print_space

    ; Print colored "●"
    ; Format: "\033[38;2;R;G;Bm●\033[0m"
    ; We'll print parts in sequence

    ; Print "\033[38;2;"
    mov rdi, 1
    mov rsi, color_prefix
    mov rdx, 7
    call write

    ; Print r as decimal
    mov eax, [r]
    call print_int

    ; Print ";"
    mov rdi, 1
    mov rsi, color_mid
    mov rdx, 1
    call write

    ; Print g as decimal
    mov eax, [g]
    call print_int

    ; Print ";"
    mov rdi, 1
    mov rsi, color_mid2
    mov rdx, 1
    call write

    ; Print b as decimal
    mov eax, [b]
    call print_int

    ; Print "m●"
    mov rdi, 1
    mov rsi, color_suffix
    mov rdx, 3
    call write

    ; Print reset color "\033[0m"
    mov rdi, 1
    mov rsi, reset_color
    mov rdx, 4
    call write

    jmp col_next

print_space:
    ; Print space
    mov rdi, 1
    mov rsi, space_char
    mov rdx, 1
    call write

col_next:
    inc edx
    jmp col_loop

after_cols:
    ; Print '|'
    mov rdi, 1
    mov rsi, pipe_char
    mov rdx, 1
    call write

    ; Print newline
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    call write

    inc ecx
    jmp row_loop

after_rows:
    ; Print bottom border: "+" + WIDTH * '-' + "+"
    mov rdi, 1
    mov rsi, border_plus
    mov rdx, 1
    call write

    mov rdi, 1
    mov rsi, border_hypen
    mov rdx, WIDTH
    call write

    mov rdi, 1
    mov rsi, border_plus
    mov rdx, 1
    call write

    ; Print newline
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    call write

    ; Print " Час: "
    mov rdi, 1
    mov rsi, hour_label
    mov rdx, 7
    call write

    ; Print hour as decimal
    mov eax, [hour]
    call print_int

    ; Print "   |   Цвет шарика: ("
    mov rdi, 1
    mov rsi, color_label
    mov rdx, 22
    call write

    ; Print r,g,b as decimal separated by ", "
    mov eax, [r]
    call print_int
    mov rdi, 1
    mov rsi, comma_space
    mov rdx, 2
    call write

    mov eax, [g]
    call print_int
    mov rdi, 1
    mov rsi, comma_space
    mov rdx, 2
    call write

    mov eax, [b]
    call print_int

    ; Print ")"
    mov rdi, 1
    mov rsi, close_paren
    mov rdx, 2
    call write

    ; Print exit message
    mov rdi, 1
    mov rsi, exit_msg
    mov rdx, 32
    call write

    ; Update x += velX
    movss xmm0, dword [x]
    movss xmm1, dword [velX]
    addss xmm0, xmm1
    movss dword [x], xmm0

    ; Update y += velY
    movss xmm0, dword [y]
    movss xmm1, dword [velY]
    addss xmm0, xmm1
    movss dword [y], xmm0

    ; Check boundaries for x
    movss xmm0, dword [x]
    movss xmm1, dword [one_float]
    comiss xmm0, xmm1
    jae check_x_upper
    ; x < 1, velX = -velX
    movss xmm2, dword [velX]
    negss xmm2, xmm2
    movss dword [velX], xmm2
    jmp check_y_bounds

check_x_upper:
    movss xmm1, dword [width_minus_2_float]
    comiss xmm0, xmm1
    jbe check_y_bounds
    ; x > WIDTH - 2, velX = -velX
    movss xmm2, dword [velX]
    negss xmm2, xmm2
    movss dword [velX], xmm2

check_y_bounds:
    ; Check boundaries for y
    movss xmm0, dword [y]
    movss xmm1, dword [one_float]
    comiss xmm0, xmm1
    jae check_y_upper
    ; y < 1, velY = -velY
    movss xmm2, dword [velY]
    negss xmm2, xmm2
    movss dword [velY], xmm2
    jmp sleep_call

check_y_upper:
    movss xmm1, dword [height_minus_2_float]
    comiss xmm0, xmm1
    jbe sleep_call
    ; y > HEIGHT - 2, velY = -velY
    movss xmm2, dword [velY]
    negss xmm2, xmm2
    movss dword [velY], xmm2

sleep_call:
    ; Sleep for 45 milliseconds = 45000 microseconds
    mov rdi, 45000
    call usleep

    jmp main_loop

; Print integer in eax to stdout
; Uses a buffer on stack, prints decimal digits
print_int:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    mov rsi, rsp        ; buffer pointer
    add rsi, 31         ; point to end of buffer
    mov byte [rsi], 0   ; null terminator

    mov ebx, eax
    cmp ebx, 0
    jne print_int_loop
    ; If zero, print '0'
    mov byte [rsi-1], '0'
    lea rsi, [rsi-1]
    mov rdx, 1
    jmp print_int_write

print_int_loop:
    xor edx, edx
print_int_div:
    mov eax, ebx
    mov ecx, 10
    div ecx
    add dl, '0'
    dec rsi
    mov [rsi], dl
    mov ebx, eax
    test ebx, ebx
    jne print_int_div

    mov rdx, rsp
    add rdx, 31
    sub rdx, rsi        ; length = end - start

print_int_write:
    mov rdi, 1
    mov rsi, rsi
    mov rdx, rdx
    call write

    mov rsp, rbp
    pop rbp
    ret

section .rodata
    half_float          dd 2.0
    velX_val            dd 1.4
    velY_val            dd 0.9
    twentythree_float   dd 23.0
    neg_35_float        dd -35.0
    neg_235_float       dd -235.0
    neg_195_float       dd -195.0
    one_float           dd 1.0
    width_minus_2_float dd WIDTH-2
    height_minus_2_float dd HEIGHT-2
    newline             db 10
    comma_space         db ',', ' '