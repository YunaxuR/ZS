

.def tmp = r24
.def tmp2 = r25
.def tmp3 = r23
.def tmp4 = r22
.def tmp5 = r17
.def tmp6 = r16
.def counter = r21
.def direction = r20  ; 0->up , 1->right, 2->down, 4->left
; SCHLANGEN OFFSET (x*8+y)
.def TailIndex = r19
.def HeadIndex = r18
.def grow_flag = r15
.def new_apple_needed = r14
.def __zero_reg__ = r1

.equ old_pinc = 0x01C7

.equ SNAKE_START = 0x01C8
.equ SNAKE_MAX   = 16

.include "m328pdef.inc"

.org 0x0000 jmp RESET
.org 0x000A jmp PCINT1_vect
.org 0x001A jmp TIMER_OVF1
.org 0x0020 jmp TIMER_OVF0

;=========================================================================
; Funktion: display
; Zeigt 64-Bit-Datenstruktur im SRAM (8x8 Pixel, 1 Bit pro Byte, LSB = Pixelzustand(0=aus/1=ein))
; Jede Zeile besteht aus 8 Bytes ? 64 Bytes insgesamt
; PORTB = Spaltenmuster (1 Bit pro Spalte)
; PORTD = Zeilenauswahl (1 aktives Bit)
;=========================================================================

display: ; 
    ;-------------------------------        
    ; Register sichern
    push tmp
    push tmp2
    push tmp3
    ;-------------------------------
    ; Z-Pointer initialisieren auf SRAM-Adresse der Displaydaten
    ldi tmp, high(0x0100)
    mov ZH, tmp
    ldi tmp, low(0x0100)
    mov ZL, tmp

    ; Zeilenauswahl starten (erste Zeile = Bit 0 aktiv)
    ldi tmp, 0b00000001     ; Zeilenwahl-Register (PORTD)

    ; Zeilenzähler
    ldi tmp4, 8

next_line:
    ; tmp2 = Bitmuster für aktuelle Zeile (Spalten)
    ldi tmp2, 0             ; Spaltenmuster aufbauen

    ; Schleife über 8 Bytes ? für 8 Pixel in der Zeile
    ldi tmp5, 8              ; Zählregister

build_row:
    ld tmp6, Z+              ; Lade Byte aus SRAM (Z zeigt automatisch auf nächste Adresse)
    andi tmp6, 0x01          ; Nur LSB ist relevant
    lsl tmp2                ; Schiebe tmp2 nach links
    or tmp2, tmp6           ; Setze LSB von tmp2 entsprechend Bitstatus
    dec tmp5
    brne build_row

    ; Spaltenmuster und Zeilenauswahl ausgeben
    com tmp2                ; Invertiere Spaltenmuster (wegen active LOW)

    ; Bitreihenfolge umdrehen
    ldi tmp3, 0             ; Zielregister für gespiegeltes Muster
    lsl tmp2
    ror tmp3
    lsl tmp2
    ror tmp3
    lsl tmp2
    ror tmp3
    lsl tmp2
    ror tmp3
    lsl tmp2
    ror tmp3
    lsl tmp2
    ror tmp3
    lsl tmp2
    ror tmp3
    lsl tmp2
    ror tmp3

    out PORTB, tmp3         ; Ausgabe des invertierten und gespiegelten Musters

    out PORTD, tmp          ; Zeilenauswahl
    rcall wait              ; kurze Anzeigepause

    ; Zeile deaktivieren für sauberen Multiplex
    ldi tmp5, 0
    out PORTD, tmp5
    ;rcall wait              ; kurze Pause zum "Löschen"

    ; Nächste Zeile vorbereiten
    lsl tmp                 ; Zeilenauswahlbit verschieben
    dec tmp4
    brne next_line

    ;-------------------------------
    ; Register wiederherstellen
    pop tmp3
    pop tmp2
    pop tmp
    ret



;	Wait function
;	- waits a defined time

wait:
	push tmp
	ldi tmp,100	; initialize counter
wait1:
	dec tmp				; decrease counter
	brne wait1			; repeat if counter not zero
	pop tmp
	ret

; Timer interrupt

TIMER_OVF1:
    ; Startwert erneut laden für nächsten Interrupt
    ldi tmp, high(0x0BDC)
    sts TCNT1H, tmp
    ldi tmp, low(0x0BDC)
    sts TCNT1L, tmp

    ; --- dein Code, exakt jede 1 Sekunde hier ---
	rcall snake_move

	; PC1 LED toggeln um Timer arbeiten zu sehen =====> TOGGLEN AUCH MÖGLICH ÜBER SBIR !
    in tmp, PORTC
    ldi tmp2, (1 << PORTC1)
    eor tmp, tmp2
    out PORTC, tmp
    reti

; 8-Bit Timer 0 OVerFlow Interrupt -- validated
TIMER_OVF0:
	rcall display
	reti
; --------- INTERRUPT ROUTINE UM AUF TASTENDRUCK DIRECTION REGISTER ZU ÄNDERN
PCINT1_vect:
	
	push tmp
    push tmp2
    push tmp3

    in tmp, PINC          ; aktueller Zustand
    lds tmp2, old_pinc    ; alter Zustand
    sts old_pinc, tmp     ; neuen Zustand merken

    ; tmp3 = Änderung von 1 ? 0 (fallende Flanke)
    mov tmp3, tmp         ; tmp3 = aktueller Zustand
    com tmp3              ; invertiere: 0 ? 1
    and tmp3, tmp2        ; nur dort, wo alt=1 und neu=0

    ; Prüfe jede Taste
    sbrs tmp3, PC2
    rjmp not_down
    ldi direction, 2

	pop tmp3
    pop tmp2
    pop tmp
    reti

not_down:

    sbrs tmp3, PC3
    rjmp not_right
    ldi direction, 1
	pop tmp3
    pop tmp2
    pop tmp
    reti

not_right:

    sbrs tmp3, PC4
    rjmp not_up
    ldi direction, 0
	pop tmp3
    pop tmp2
    pop tmp
    reti

not_up:

    sbrs tmp3, PC5
    rjmp not_left
    ldi direction, 4
	pop tmp3
    pop tmp2
    pop tmp
    reti
   
not_left:

    pop tmp3
    pop tmp2
    pop tmp
    reti


RESET:
	; Stack initialization -- validated
	ldi	tmp,LOW(RAMEND)		
	out	SPL,tmp				
	ldi	tmp,HIGH(RAMEND)	
	out	SPH,tmp	

	;-----------------------------
	; SRAM 0x0100–0x013F (64 Bytes) mit 0 füllen - DISPLAY DATENSTRUKTUR
	;-----------------------------
	ldi ZH, high(0x0100)   ; Zeiger auf Startadresse
	ldi ZL, low(0x0100)

	ldi tmp, 0x00          ; Wert 0 zum Schreiben
	ldi tmp2, 64           ; 64 Bytes

	clear_sramD:
		st Z+, tmp         ; Schreibe 0, Inkrementiere Z
		dec tmp2
		brne clear_sramD   ; Wiederholen bis alle 64 geschrieben

	;-----------------------------
	; SRAM 0x01C8–xxxx (SNAKE_MAX Bytes) mit 0 füllen - SCHLANGE DATENSTRUKTUR
	;-----------------------------
	ldi ZH, high(SNAKE_START)   ; Zeiger auf Startadresse
	ldi ZL, low(SNAKE_START)
	ldi tmp, 0
	ldi tmp2, 64
	clear_sramS:
		st Z+, tmp
		dec tmp2
		brne clear_sramS

	; Port B and D as LED Output -- validated
	ldi tmp, 0b11111111
	out DDRB, tmp
	out DDRD, tmp

	; Button pins as input with pullup LED pin as output -- validated
	ldi tmp,0b00000010
	out DDRC, tmp
	ldi tmp, 0b00111110
	out PORTC, tmp

	; ADC RESET&INIT ROUTINE
	ldi tmp, (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0) ; Prescaler 128
	sts ADCSRA, tmp

	ldi tmp, (1 << REFS0) ; AVcc als Referenz, ADC0 als Kanal (oder ändern)
	sts ADMUX, tmp
	rcall wait
	rcall read_adc_scaled


	; ======= TIMER SETZEN ==========
	; ===============================

	; Initialize 16-Bit Counter1 for OVF interrupt
	;ldi tmp, 0b00000011
	;sts TCCR1B, tmp
	;ldi tmp, 0b00000000 ; 0b00000001 zum aktivieren - GERADE DEAKTIVIERT
	;sts TIMSK1, tmp

	ldi tmp, (1<<CS11)|(1<<CS10)   ; CS12:0, CS11:1, CS10:1 ? Prescaler = 64
	sts TCCR1B, tmp
	ldi tmp, (1<<TOIE1)
	sts TIMSK1, tmp
	ldi tmp, high(0x0BDC)
	sts TCNT1H, tmp
	ldi tmp, low(0x0BDC)
	sts TCNT1L, tmp

	; Initialize  8-Bit Counter0 for OVF interrupt with 512 prescaler -- validated
	ldi tmp, 0b00000001
	out TCCR0B, tmp
	ldi tmp, 0b00000000 ; 0b00000001 zum aktivieren - GERADE DEAKTIVIERT
	sts TIMSK0, tmp

	; Speichere PINC für fallende Flanken Erkennung
	in tmp, PINC
	sts old_pinc, tmp

	; Aktiviere PCINT10–13 (PC2–PC5)
	ldi r16, (1 << PCINT10) | (1 << PCINT11) | (1 << PCINT12) | (1 << PCINT13)
	sts PCMSK1, r16          ; PCMSK1 für Port C

	; Aktiviere Pin Change Interrupt für Port C (PCIE1)
	ldi r16, (1 << PCIE1)
	sts PCICR, r16

	
	;sei
	cli
	rjmp start

	



	
start:


	; PC2–PC5 sind Eingänge mit Pullup (also: gedrückt = 0)
    ; Lies PINC und prüfe, ob einer der Bits 2–5 = 0 ist


wait_for_button:

	; Z-Pointer auf Startpixel setzen
	ldi ZH, high(0x0100)
	ldi ZL, low(0x011B)
	ldi tmp, 1
	st Z, tmp

	in tmp, PINC          ; Lese aktuellen Zustand

	sbrs tmp, 2           ; Prüfe PC2 (Down), überspringe wenn NICHT gedrückt
	rjmp button_down

	sbrs tmp, 3           ; Prüfe PC3 (Right)
	rjmp button_right

	sbrs tmp, 4           ; Prüfe PC4 (Up)
	rjmp button_up

	sbrs tmp, 5           ; Prüfe PC5 (Left)
	rjmp button_left
    

    rjmp wait_for_button        ; Jetzt ins Hauptprogramm springen


button_down:
	; Direction-Register setzen
	ldi direction, 2
	
	; Apfel setzen
	rcall set_apfel

	; Spiel Starten
	rcall snake_init
	; WICHTIG: alten Zustand aktualisieren, bevor Interrupt aktiviert wird!
    in tmp, PINC
    sts old_pinc, tmp
	sei ; -- INTERRUPT AKTIVIEREN
	rjmp main_loop

button_right:
	; Direction-Register setzen
	ldi direction, 1


	; Apfel setzen
	rcall set_apfel
	
	; Spiel Starten
	rcall snake_init
	; WICHTIG: alten Zustand aktualisieren, bevor Interrupt aktiviert wird!
    in tmp, PINC
    sts old_pinc, tmp
	sei ; -- INTERRUPT AKTIVIEREN
	rjmp main_loop

button_up:
	; Direction-Register setzen
	ldi direction, 0

	; Apfel setzen
	rcall set_apfel
	
	; Spiel Starten
	rcall snake_init
	; WICHTIG: alten Zustand aktualisieren, bevor Interrupt aktiviert wird!
    in tmp, PINC
    sts old_pinc, tmp
	sei ; -- INTERRUPT AKTIVIEREN
	rjmp main_loop

button_left:
	; Direction-Register setzen
	ldi direction, 4

	; Apfel setzen
	rcall set_apfel
	
	; Spiel Starten
	rcall snake_init
	; WICHTIG: alten Zustand aktualisieren, bevor Interrupt aktiviert wird!
    in tmp, PINC
    sts old_pinc, tmp
	sei ; -- INTERRUPT AKTIVIEREN
	rjmp main_loop

main_loop:
	
	tst new_apple_needed
	breq skip_apple
	rcall set_apfel
	ldi tmp, 0
	mov new_apple_needed, tmp
	skip_apple:


	rcall display

	


    rjmp main_loop






; ADC Messung

read_adc_scaled:
    ; Starte Messung
    lds tmp, ADCSRA ; Analog-to-Digital Converter Status and Control Register A
    ori tmp, (1 << ADSC) ; ADSC-> ADC Start Conversion  1 -> Messung Starten ---- Solange ADSC = 1, ist Messung noch aktiv
    sts ADCSRA, tmp

wait_adc:
    lds tmp, ADCSRA
    sbrc tmp, ADSC
    rjmp wait_adc

    ; ADCL zuerst lesen, dann ADCH!
    lds tmp2, ADCL
    lds tmp3, ADCH

    ; Skaliere 10 Bit auf 6 Bit (0–63)
    lsr tmp3
    ror tmp2
    lsr tmp3
    ror tmp2
    lsr tmp3
    ror tmp2
    lsr tmp3
    ror tmp2

    ; Jetzt ist tmp2 = Wert 0–63

    ret





; =========== APFEL GENERATOR ========================
; --------------- GENERTIERT WERT IN tmp2 von 0-63 und lässt diesen Pixel dann aufleuchten im SRAM bzw, setzt ihn auf 3  ---------
; TODO ----> PRÜFEN OB PIXEL BEREITS AN IST. WENN JA -> set_rpixel ERNEUT AUFRUFEN
set_apfel:

	cli
    push tmp
    push tmp2
    push tmp3
    push tmp4
    push ZL
    push ZH
    

    ; hole erste Zufallsposition
    rcall read_adc_scaled        ; tmp2 = Startposition (0–63)

    ldi tmp4, 64                 ; Maximal 64 Versuche (alle Felder prüfen)

find_free_pixel_loop:
    ; Z auf Adresse 0x0100 + tmp2
    ldi ZH, high(0x0100)
    ldi ZL, low(0x0100)
    add ZL, tmp2
    adc ZH, __zero_reg__

    ; Pixel prüfen
    ld tmp3, Z
    tst tmp3
    breq pixel_found

    ; wenn nicht frei ? nächsten Pixel prüfen
    inc tmp2
    cpi tmp2, 64
    brlo skip_wrap  
    ldi tmp2, 0
skip_wrap:
    dec tmp4                     ; Versuch zählen
    brne find_free_pixel_loop

    ; Wenn hier ? alle 64 Pixel belegt (Game Over!)
    sei
    pop ZH
    pop ZL
    pop tmp4
    pop tmp3
    pop tmp2
    pop tmp
    rjmp game_over               ; alle Pixel belegt ? Ende!

pixel_found:
    ; Pixel auf Wert „3“ setzen (Apfel)
    ldi tmp, 3
    st Z, tmp

	pop ZH
    pop ZL
    pop tmp4
    pop tmp3
    pop tmp2
    pop tmp
    sei
    ret



; ==================== SNAKE MOVE ROUTINE (1 SCHRITT IN AKTUELLE RICHUNG) =======================
; ===============================================================================================

;=====================================================
; Snake bewegt sich 1 Schritt in aktuelle Richtung
; - prüft auf Kollision
; - erkennt Apfel
; - setzt neuen Kopf
; - löscht alten Schwanz (nur wenn nicht wachsen)
;=====================================================
snake_move:
    push tmp
    push tmp2
    push tmp3
    push tmp4
	push tmp5

    ;===========================
    ; 1. aktuellen Kopf holen
    ldi ZH, high(SNAKE_START)
    ldi ZL, low(SNAKE_START)
    add ZL, HeadIndex
    adc ZH, __zero_reg__
    ld tmp, Z    ; tmp = aktueller Offset im Spielfeld

    ;===========================
    ; 2. neuen Kopf berechnen
    cpi direction, 0       ; UP
    brne check_right
	ldi tmp5, 8
    add tmp,tmp5
    rjmp direction_ok

check_right:
    cpi direction, 1
    brne check_down
    inc tmp
    rjmp direction_ok

check_down:
    cpi direction, 2
    brne check_left
    subi tmp, 8
    rjmp direction_ok

check_left:
    cpi direction, 4
    brne direction_error
    dec tmp
    rjmp direction_ok

direction_error:
    rjmp game_over

direction_ok:
    ;===========================
    ; 3. Feld prüfen
    ldi ZH, high(0x0100)
    ldi ZL, low(0x0100)
    add ZL, tmp
    adc ZH, __zero_reg__
    ld tmp2, Z
    cpi tmp2, 1
    breq game_over         ; Kollision mit sich selbst
    cpi tmp2, 3
    brne not_apple
	; APFEL ERKANNT ----- 1. Setze grow_flag 2. Lösche Apfel aus Feld :::: MUSS NICHT NOCH NEUER APFEL GESETZT WERDEN?
	ldi tmp4, 1
	mov grow_flag, tmp4
	ldi tmp4, 0
	st Z, tmp4
	ldi tmp4, 1
	mov new_apple_needed, tmp4
	
    rjmp store_head

not_apple:
	ldi tmp4, 0
	mov grow_flag, tmp4

store_head:
    ;===========================
    ; 4. neuen Kopf ins Spielfeld setzen !!!!!!!!!!!!!! MUSS Z NICHT NOCH UM 1 ERHÖHRT WERDEN?
    ldi tmp2, 1
    st Z, tmp2

    ;===========================
    ; 5. neuen Kopf im Snake-Puffer speichern
    inc HeadIndex
    cpi HeadIndex, SNAKE_MAX
    brlo skip_wrap_h
    ldi HeadIndex, 0
skip_wrap_h:

    ldi ZH, high(SNAKE_START)
    ldi ZL, low(SNAKE_START)
    add ZL, HeadIndex
    adc ZH, __zero_reg__
    st Z, tmp

    ;===========================
    ; 6. Schwanz löschen wenn nicht wachsen
    tst grow_flag
    brne skip_tail_delete

    ; Tail-Offset holen
    ldi ZH, high(SNAKE_START)
    ldi ZL, low(SNAKE_START)
    add ZL, TailIndex
    adc ZH, __zero_reg__
    ld tmp3, Z

    ; Pixel auf 0 setzen
    ldi ZH, high(0x0100)
    ldi ZL, low(0x0100)
    add ZL, tmp3
    adc ZH, __zero_reg__
    ldi tmp4, 0
    st Z, tmp4

    ; TailIndex++
    inc TailIndex
    cpi TailIndex, SNAKE_MAX
    brlo skip_wrap_t
    ldi TailIndex, 0
skip_wrap_t:

    ;dec counter        ; Länge bleibt gleich
    rjmp finish

skip_tail_delete:
    ; Schlange wächst
    ; counter erhöhen
    inc counter
	;rcall set_apfel !!!!! TESTWEISE AUS UND DURCH APPLENEEDEDFLAG ERSETZT
    cpi counter, SNAKE_MAX
    brlo finish
    ; Wenn counter > MAX ? Game Over
    rjmp game_over

finish:
	
	pop tmp5
    pop tmp4
    pop tmp3
    pop tmp2
    pop tmp
    ret

game_over:
    ; TODO: LEDs aus, Endlosschleife etc.
    rjmp game_over





;============================= SCHLANGE INITIALISIERUNG ================================
snake_init:
	; SPIELFELD: zwei Pixel setzen (Offsets 26 und 27)
	ldi ZH, high(0x0100)
	ldi ZL, low(0x0100)
	ldi tmp, 1

	; Schwanz: Offset 26 ? Adresse 0x0100 + 26 = 0x011A
	ldi tmp2, 26
	add ZL, tmp2
	adc ZH, __zero_reg__
	st Z, tmp

	; Kopf: Offset 27 ? Adresse 0x0100 + 27 = 0x011B
	ldi ZH, high(0x0100)
	ldi ZL, low(0x0100)
	ldi tmp2, 27
	add ZL, tmp2
	adc ZH, __zero_reg__
	st Z, tmp

	;=============================
	; RINGPUFFER: 26 und 27 speichern
	ldi ZH, high(SNAKE_START)
	ldi ZL, low(SNAKE_START)
	ldi tmp2, 26
	st Z+, tmp2
	ldi tmp2, 27
	st Z, tmp2

	;=============================
	; REGISTER setzen
	ldi HeadIndex, 1      ; Zeigt auf Kopf (Position mit 27)
	ldi TailIndex, 0      ; Zeigt auf Schwanz (Position mit 26)
	ldi counter, 2        ; Länge = 2

	ret
