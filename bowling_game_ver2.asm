

org 100h

jmp start


;Data
ball_start_x db 20  ;ball start pos x and y
ball_start_y db 09h  

prev_ball_x db 20  ;prev ball positions
prev_ball_y db 09h

ball_x db 20    ;ball pos x and y
ball_y db 09h   

dir_x db 0        ; horiz vector
dir_y db 0        ; vertical vector/starting power

launched db 0     ; launched state

pin_x db 50, 55, 55, 60, 60   ; pins x and y pos and alive states
pin_y db 9, 11, 7 ,9 , 6  
pin_alive db 1, 1, 1, 1, 1
pin_count db 5
lives db 5                    ;lives and remaining pins
remaining_pins db 5

;Messsages 
controls_msg db 'WASD: Power | SPACE: Launch$',0
gameover_msg db 'GAME OVER$',0
win_msg db 'YOU WIN!$',0



;random seed
rand db 53

;screen bounds                                    
screen_left db 00
screen_top db 00
screen_right db 79
screen_bot   db 24



;Baslangic ve ana dongu
start:
mov ax, 0003h
int 10h
call reset_pins
main_loop:

    call handle_input
    call update_ball
    call check_collision
    call draw_scene

    jmp main_loop



                        
;input handling
handle_input:
    mov ah, 01h 
    int 16h    ;int 16h AH=01h keyboarddan char girilmis mi diye kontrol eder varsa ZF =1 Yoksa ZF = 0
    jz no_key  ;ZF 0 ise no key gider

    mov ah, 00h ;int 16h 00h keyboarddan input alir (getchar gibi) ve AL'ye koyar 
    int 16h
    
    cmp launched,1
    je no_key
    
    cmp al, 'a'      ;girilen keye gore operasyonlar
    je horiz_sub   

    cmp al, 'd'
    je horiz_inc

    cmp al, 'w'
    je vertic_inc
    
    cmp al, 's'
    je vertic_sub

    cmp al, 20h
    je launch

    jmp no_key

horiz_sub:
    add dir_x, -1
    jmp no_key

horiz_inc:
    add dir_x, 1
    jmp no_key

vertic_inc:   
    add dir_y,1
    jmp no_key
    
vertic_sub:   
    add dir_y,-1    
    jmp no_key
    
launch:
    mov launched, 1

no_key:
    ret


;Top pozisyonu guncelleme
update_ball:

    cmp launched, 1
    jne not_launched
    
    
    mov al, ball_x
    mov prev_ball_x, al
    
    mov al, ball_y
    mov prev_ball_y, al

    ; ball_x += dir_x
    mov al, ball_x
    add al, dir_x
    mov ball_x, al

    ; ball_y += dir_y
    mov al, ball_y
    mov bl, dir_y
    neg bl
    add al, bl
    mov ball_y, al
    
    ; out of bounds kontrolu
    call check_bounds
    ret


done_update:
    ret

not_launched:
    ret 

;out of bounds kontrolu ve sekme islemleri    
check_bounds:
    mov al, ball_x
    cmp al, screen_left
    jl bounce_left

    mov al, ball_x      ;top sadece sag duvardan resetlenir
    cmp al, screen_right
    ja reset_ball


    mov al, ball_y
    cmp al, screen_top
    jl bounce_top

    mov al,ball_y
    cmp al, screen_bot
    jg bounce_bottom

    ret
    
bounce_left:
    neg dir_x
    mov al, screen_left
    inc al
    mov ball_x, al
    ret
    
bounce_top:
    neg dir_y
    mov al, screen_top
    inc al
    mov ball_y, al
    ret

bounce_bottom:
    neg dir_y
    mov al, screen_bot
    dec al
    mov ball_y, al
    ret
    


       
;pinlerle carpisma kontrolu    
check_collision:
    mov si, 0
    xor cx, cx
    mov cl, pin_count

collision_loop:         ;top ile olan mutlak mesafeye bakilarak
                        ;carpisma yapilir
    cmp [pin_alive+si], 1
    jne next_pin
    ;dx = ball_x - pin_x
    mov al, ball_x
    sub al, [pin_x+si]

    ;mutlak deger alinir
    cmp al, 0
    jge x_ok
    neg al

x_ok:
    cmp al, 1   
    ja next_pin      
    ;dy = ball_y - pin_y
    mov al, ball_y
    sub al, [pin_y+si]

    ;mutlak deger alinir
    cmp al, 0
    jge y_ok
    neg al

y_ok:
    cmp al, 1
    ja next_pin      

    ;carpisma olayi
    mov [pin_alive+si], 0
    dec remaining_pins
    
    ;pin silinmesi (pin yerine bosluk ' ' yazilir)
    mov al, [pin_x+si]
    mov ah, [pin_y+si]
    mov bl, ' '
    call draw_char
        
    cmp remaining_pins, 0 ;kalan pin yoksa oyun kazanilmis demektir
    jne continue_game     ;pin varsa devam edilir
    
    call game_won
    
    continue_game:
    ret

next_pin:
    inc si
    loop collision_loop

    ret
    
no_hit:
    ret
                         

;top pozisyonu ve state sifirlama
reset_ball:

    dec lives   ;top resetlendiginde -1 can

    mov al,ball_start_x     
    mov ball_x, al
    
    mov al,ball_start_y
    mov ball_y, al
    
    mov dir_x, 0
    mov dir_y, 0
    mov launched, 0

    ;eger can kalmadiysa oyun bitirilir
    cmp lives, 0
    je do_game_over
    
    call reset_pins     
    ret
    
    do_game_over:
    call game_over
    ret
    
reset_pins:
    mov ah, 00h
    int 1Ah        ;random sayi icin bios saati
    add [rand], dl 
    
    mov si, 0
    xor cx, cx
    mov cl, [pin_count] 

pin_reset_loop:
    cmp byte [pin_alive+si], 1
    jne skip_spawn

    ;pinleri geri dagitmadan once eski pinler silinir
    mov al, [pin_x+si]
    mov ah, [pin_y+si]
    mov bl, ' '
    call draw_char

retry_spawn:        ;eger pin icin unique pozisyon  
    mov al, [rand]  ;bulunamadiysaretry spawn cagirilir
    add al, 37
    xor al, 0xA7
    mov [rand], al
    
    xor ah, ah
    mov bl, 30
    div bl
    mov al, ah
    add al, ball_start_x
    add al, 15
    
    cmp al, screen_right
    jbe store_x
    mov al, screen_right
    dec al
store_x:
    mov [pin_x+si], al 
    
    ;rastgele Y koordinati
    mov al, [rand]
    add al, 19
    xor al, 0x3D
    mov [rand], al
    
    xor ah, ah
    mov bl, 20
    div bl
    mov al, ah
    add al, 2
    mov [pin_y+si], al

    ;Overlap kontrolu
    push cx             ;Dis dongudeki index saklanir
    mov di, 0
overlap_check_loop:
    cmp di, si          
    je overlap_done
                       ;pozisyonlar kontrol edilir
    mov al, [pin_x+si]
    cmp al, [pin_x+di]  
    jne next_overlap_check
    
    mov al, [pin_y+si]
    cmp al, [pin_y+di]  
    jne next_overlap_check
    
                    ;X ve Y ayni ise dis dongu indexi
    pop cx          ;geri verilir ve tekrar random sayi alinir
    jmp retry_spawn     

next_overlap_check:
    inc di
    jmp overlap_check_loop

overlap_done:
    pop cx            

skip_spawn:
    inc si
    loop pin_reset_loop
    ret
    
 
 
    
;ekrana cizim
draw_scene:
        
    call draw_ui
    
    ;eski topun silinmesi
    mov al, prev_ball_x
    mov ah, prev_ball_y
    mov bl, ' '
    call draw_char

    ;yeni top cizimi
    mov al, ball_x
    mov ah, ball_y
    mov bl, 'O'
    call draw_char
    
    ;pinlerin cizimi
    call draw_pins

skip_pin:
    ret


draw_pins:

    mov si, 0
    xor cx, cx
    mov cl, pin_count

draw_pin_loop:

    cmp [pin_alive+si], 1
    jne skip_this_pin

    mov al, [pin_x+si]
    mov ah, [pin_y+si]
    mov bl, '|'
    call draw_char

skip_this_pin:
    inc si
    loop draw_pin_loop

    ret


;ust koseye can,kalan pin ve kontrollerin yazilmasi    
draw_ui:
    mov dh, 0       
    mov dl, 0       
    call set_cursor
    mov si, offset controls_msg
    call draw_string

    ;canlarin yazilmasi
    mov al, 0       
    mov ah, 1       
    mov bl, 'L'
    call draw_char

    mov al, 1
    mov ah, 1
    mov bl, ':'
    call draw_char

    mov al, lives
    add al, '0'
    mov ah, 1
    mov bl, al
    mov al, 3
    call draw_char

    ;pinlerin yazilmasi
    mov al, 10
    mov ah, 1
    mov bl, 'P'
    call draw_char

    mov al, 11
    mov ah, 1
    mov bl, ':'
    call draw_char

    mov al, remaining_pins
    add al, '0'
    mov ah, 1
    mov bl, al
    mov al, 13
    call draw_char

    ret
    
    
;kaybetme ekrani    
game_over:

    call clear_screen

    mov si, offset gameover_msg

    mov dh, 12      
    mov dl, 35      
    call set_cursor

    call draw_string

hang:
    jmp hang   


;kazanma ekrani
game_won:

    call clear_screen

    mov si, offset win_msg

    mov dh, 12
    mov dl, 30
    call set_cursor

    call draw_string

hang2:
    jmp hang2
    
set_cursor:
    mov bh, 0
    mov ah, 02h
    int 10h
    ret

        
; karakter cizimi
; AL = x, AH = y, BL = char
draw_char:
    push ax
    push bx
    push dx

    mov bh, 0
    mov dh, ah   ; satir
    mov dl, al   ; sutun
    mov ah, 02h
    int 10h      ; int 10h 02 ekrana kar cizimi yapar 

    mov ah, 0Eh  ;int 10h 0E cursorun 
    mov al, bl   ;oldugu yere AL'deki chari yazar
    int 10h

    pop dx
    pop bx
    pop ax
    ret 
    
draw_string:
.next_char:
    lodsb
    cmp al, '$'
    je .done

    mov ah, 0Eh
    mov bh, 0
    int 10h     

    jmp .next_char
.done:
    ret
    
;ekran temizleme islemi 

clear_screen:
    mov ax, 0600h 
    mov bh, 07h  

    mov ch, screen_top     
    mov cl, screen_left    
    mov dh, screen_bot     
    mov dl, screen_right   

    int 10h
    ret    
     