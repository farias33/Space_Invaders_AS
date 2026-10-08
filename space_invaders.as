;==============================================================================
;                         S P A C E   I N V A D E R S
;                    Jogo para o processador P3 (Assembly)
;------------------------------------------------------------------------------
; Controles (Janela de Texto - clicar no centro da janela para ler teclas):
;       A / D   : move a nave para a esquerda / direita
;       ESPACO  : atira (tambem inicia o jogo)
;       P       : pausa / continua
; Botoes da Janela Placa:
;       I0 = esquerda   I1 = tiro   I2 = direita
;
; Perifericos usados:
;       Janela de Texto  (FFFCh-FFFFh) : desenho do jogo e leitura do teclado
;       Temporizador     (FFF6h/FFF7h) : relogio do jogo (interrupcao 15)
;       Mascara de int.  (FFFAh)       : habilita temporizador e botoes I0-I2
;       Display 7 seg.   (FFF0h-FFF3h) : pontuacao (4 digitos menos signif.)
;       LEDs             (FFF8h)       : vidas restantes
;       LCD              (FFF4h/FFF5h) : titulo e numero da onda
;
; Convencao das rotinas: argumentos e retornos em registradores (descritos no
; cabecalho de cada rotina). Todos os outros registradores sao preservados.
;==============================================================================

;------------------------------------------------------------------------------
; ZONA I: Definicao de constantes
;         Pseudo-instrucao : EQU
;------------------------------------------------------------------------------
; Enderecos de E/S
FIM_TEXTO       EQU     '@'
IO_READ         EQU     FFFFh
IO_WRITE        EQU     FFFEh
IO_STATUS       EQU     FFFDh
INITIAL_SP      EQU     FDFFh
CURSOR          EQU     FFFCh
CURSOR_INIT     EQU     FFFFh
ROW_SHIFT       EQU     8d

TIMER_UNITS     EQU     FFF6h
ACTIVATE_TIMER  EQU     FFF7h
INT_MASK_ADDR   EQU     FFFAh
INT_MASK        EQU     8007h   ; temporizador (15) + botoes I0, I1 e I2
LEDS            EQU     FFF8h
DISP7_D0        EQU     FFF0h   ; display de 7 segmentos mais a direita
DISP7_COUNT     EQU     4d
LCD_CTRL        EQU     FFF4h
LCD_WRITE       EQU     FFF5h
LCD_CLEAR       EQU     8020h   ; liga (bit 15) e limpa (bit 5) o LCD
LCD_LINE0       EQU     8000h   ; liga + linha 0, coluna 0
LCD_LINE1       EQU     8010h   ; liga + linha 1, coluna 0
LCD_WAVE_POS    EQU     8016h   ; linha 1, coluna 6 (unidades da onda)

ON              EQU     1d
OFF             EQU     0d

; Relogio do jogo
TICK_TIME       EQU     1d      ; unidades de 100ms entre interrupcoes
DEATH_PAUSE     EQU     8d      ; ticks de pausa quando a nave e atingida
WAVE_PAUSE      EQU     15d     ; ticks de pausa entre ondas

; Numero aleatorio (mesma tecnica do exemplo Random.as)
RND_MASK        EQU     8016h   ; 1000 0000 0001 0110b
LSB_MASK        EQU     0001h
RND_SEED        EQU     A5A5h
FIRE_MASK       EQU     0003h   ; aliens atiram com probabilidade 1/4 por tick

; Teclas
KEY_LEFT        EQU     'a'
KEY_RIGHT       EQU     'd'
KEY_FIRE        EQU     20h     ; espaco
KEY_PAUSE       EQU     'p'
CASE_MASK       EQU     20h     ; OR com 20h converte maiuscula em minuscula

; Caracteres
BLANK           EQU     20h
SHOT_CHAR       EQU     '|'
BOMB_CHAR       EQU     '*'
BUNKER_CHAR     EQU     '#'
GROUND_CHAR     EQU     '-'

; Layout da tela (janela de texto: linhas 0-23, colunas 0-79)
HUD_ROW         EQU     0d
HUD_SCORE_COL   EQU     2d
HUD_SCORE_VAL   EQU     10d
SCORE_DIGITS    EQU     5d
HUD_WAVE_COL    EQU     30d
HUD_WAVE_VAL    EQU     36d
WAVE_DIGITS     EQU     2d
HUD_PAUSE_COL   EQU     48d
HUD_LIVES_COL   EQU     66d
HUD_LIVES_VAL   EQU     73d
LIVES_DIGITS    EQU     1d
TOP_ROW         EQU     1d      ; primeira linha onde o tiro pode estar
GROUND_ROW      EQU     22d
LEFT_LIMIT      EQU     1d
RIGHT_LIMIT     EQU     78d
MSG_ROW         EQU     12d
MSG_COL         EQU     32d
DECIMAL_BASE    EQU     10d

; Formacao de aliens
ALIEN_ROWS      EQU     5d
ALIEN_COLS      EQU     11d
NUM_ALIENS      EQU     55d
LAST_ROW_BASE   EQU     44d     ; indice do 1o alien da ultima linha
LAST_ALIEN_ROW  EQU     4d
ALIEN_WIDTH     EQU     3d
ALIEN_HSTEP     EQU     5d      ; distancia horizontal entre aliens
ALIEN_VSTEP     EQU     2d      ; distancia vertical entre aliens
FORM_ROW0       EQU     3d      ; linha inicial da formacao (onda 1)
FORM_ROW_MAX    EQU     6d      ; linha inicial maxima (ondas seguintes)
FORM_COL0       EQU     12d
DIR_RIGHT       EQU     1d
DELAY_SHIFT     EQU     3d      ; atraso = aliens_vivos / 8 + 1 ticks
INVASION_ROW    EQU     18d     ; aliens nesta linha = fim de jogo

; Sprites (3 caracteres)
SPRITE_WIDTH    EQU     3d      ; tambem e o deslocamento do 2o quadro

; Jogador
PLAYER_ROW      EQU     21d
PLAYER_COL0     EQU     38d
PLAYER_WIDTH    EQU     3d
PLAYER_STEP     EQU     2d
PLAYER_MAX_COL  EQU     76d     ; RIGHT_LIMIT - PLAYER_WIDTH + 1
SHOT_START_ROW  EQU     20d     ; PLAYER_ROW - 1
LIVES_INIT      EQU     3d
FIRST_WAVE      EQU     1d

; Bombas dos aliens
MAX_BOMBS       EQU     3d

; Barreiras: 4 barreiras de 2 linhas x 5 colunas
BUNKER_ROW      EQU     18d
BUNKER_HEIGHT   EQU     2d
BUNKER_END_ROW  EQU     20d     ; BUNKER_ROW + BUNKER_HEIGHT
BUNKER_WIDTH    EQU     5d
BUNKER_SIZE     EQU     10d     ; celulas por barreira
BUNKER_COUNT    EQU     4d
BUNKER_CELLS    EQU     40d
BUNKER_COL0     EQU     13d
BUNKER_STEP     EQU     16d

; Estados do jogo
STATE_PLAYING   EQU     0d
STATE_GAMEOVER  EQU     1d
STATE_WAVE_DONE EQU     2d

; Fim de um bloco de textos (ver PrintBlock)
TABLE_END       EQU     FFFFh
TEXT_HEADER     EQU     2d      ; linha e coluna antes de cada texto

;------------------------------------------------------------------------------
; ZONA II: definicao de variaveis
;          Pseudo-instrucoes : WORD - palavra (16 bits)
;                              STR  - sequencia de caracteres (cada ocupa 1 palavra: 16 bits).
;                              TAB  - reserva posicoes de memoria
;------------------------------------------------------------------------------
                ORIG    8000h
Random_Var      WORD    RND_SEED
TimerFlag       WORD    0d      ; colocado a 1 pela interrupcao do temporizador
ButtonKey       WORD    0d      ; tecla gerada pelos botoes da placa
GameState       WORD    STATE_PLAYING
Paused          WORD    OFF
Score           WORD    0d
HighScore       WORD    0d
Lives           WORD    LIVES_INIT
Wave            WORD    FIRST_WAVE
PlayerCol       WORD    PLAYER_COL0

FormRow         WORD    FORM_ROW0   ; linha do canto superior esquerdo
FormCol         WORD    FORM_COL0   ; coluna do canto superior esquerdo
FormDir         WORD    DIR_RIGHT   ; +1 direita, -1 esquerda
AnimFrame       WORD    0d          ; 0 ou SPRITE_WIDTH (quadro da animacao)
MoveCounter     WORD    1d          ; ticks ate o proximo passo da formacao
AliensLeft      WORD    NUM_ALIENS

ShotActive      WORD    OFF
ShotRow         WORD    0d
ShotCol         WORD    0d

; Obs.: TAB usa literais porque alguns assemblers do P3 (ex.: p3js) nao
;       aceitam simbolos EQU nesta pseudo-instrucao
BombActive      TAB     3d          ; MAX_BOMBS
BombRow         TAB     3d          ; MAX_BOMBS
BombCol         TAB     3d          ; MAX_BOMBS

AlienAlive      TAB     55d         ; NUM_ALIENS: 1 = vivo, indice = linha*11+coluna
Bunker          TAB     40d         ; BUNKER_CELLS

; Sprites: cada tipo tem 2 quadros de 3 caracteres seguidos
SpriteA         STR     '<o>>o<'
SpriteB         STR     '(M))M('
SpriteC         STR     '{W}}W{'
PlayerSprite    STR     '=A='
ExplodeSprite   STR     'x*x'

; Deslocamento do sprite (a partir de SpriteA) e pontos de cada linha
RowSprite       STR     0d, 6d, 6d, 12d, 12d
AlienPoints     STR     30d, 20d, 20d, 10d, 10d

; Textos
StrScore        STR     'PONTOS:', FIM_TEXTO
StrWave         STR     'ONDA:', FIM_TEXTO
StrLives        STR     'VIDAS:', FIM_TEXTO
StrPause        STR     'PAUSA', FIM_TEXTO
StrNoPause      STR     '     ', FIM_TEXTO
StrWaveDone     STR     'ONDA CONCLUIDA!', FIM_TEXTO
StrLcdTitle     STR     'SPACE INVADERS', FIM_TEXTO
StrLcdWave      STR     'ONDA ', FIM_TEXTO
StrLcdOver      STR     'GAME OVER', FIM_TEXTO

; Blocos de texto: cada linha e (linha, coluna, texto, FIM_TEXTO);
; o bloco termina com TABLE_END
TitleText       STR     4d, 26d, 'S P A C E    I N V A D E R S', FIM_TEXTO
TitleText1      STR     8d, 30d, '<o>   =   30 PONTOS', FIM_TEXTO
TitleText2      STR     9d, 30d, '(M)   =   20 PONTOS', FIM_TEXTO
TitleText3      STR     10d, 30d, '{W}   =   10 PONTOS', FIM_TEXTO
TitleText4      STR     13d, 30d, 'A / D    mover a nave', FIM_TEXTO
TitleText5      STR     14d, 30d, 'ESPACO   atirar', FIM_TEXTO
TitleText6      STR     15d, 30d, 'P        pausar', FIM_TEXTO
TitleText7      STR     17d, 15d, 'Botoes da placa: I0 esquerda  I1 tiro  I2 direita', FIM_TEXTO
TitleText8      STR     20d, 25d, 'Pressione ESPACO para comecar', FIM_TEXTO
TitleTextEnd    WORD    TABLE_END

GameOverText    STR     8d, 31d, 'G A M E    O V E R', FIM_TEXTO
GameOverText1   STR     11d, 28d, 'PONTUACAO FINAL:', FIM_TEXTO
GameOverText2   STR     13d, 28d, 'RECORDE:', FIM_TEXTO
GameOverText3   STR     17d, 22d, 'Pressione ESPACO para jogar de novo', FIM_TEXTO
GameOverEnd     WORD    TABLE_END
FINAL_ROW       EQU     11d
RECORD_ROW      EQU     13d
FINAL_VAL_COL   EQU     45d

;------------------------------------------------------------------------------
; ZONA III: definicao de tabela de interrupcoes
;------------------------------------------------------------------------------
                ORIG    FE00h
INT0            WORD    ButtonLeft
INT1            WORD    ButtonFire
INT2            WORD    ButtonRight

                ORIG    FE0Fh
INT15           WORD    Timer

;------------------------------------------------------------------------------
; ZONA IV: codigo
;        conjunto de instrucoes Assembly, ordenadas de forma a realizar
;        as funcoes pretendidas
;------------------------------------------------------------------------------
                ORIG    0000h
                JMP     Main

;==============================================================================
; Rotinas de interrupcao
;==============================================================================

;------------------------------------------------------------------------------
; Timer: avisa o ciclo principal que passou um tick e rearma o temporizador
;------------------------------------------------------------------------------
Timer:          PUSH    R1
                MOV     R1, ON
                MOV     M[ TimerFlag ], R1
                CALL    ConfigureTimer
                POP     R1
                RTI

;------------------------------------------------------------------------------
; Botoes I0, I1 e I2: simulam as teclas de esquerda, tiro e direita
;------------------------------------------------------------------------------
ButtonLeft:     PUSH    R1
                MOV     R1, KEY_LEFT
                MOV     M[ ButtonKey ], R1
                POP     R1
                RTI

ButtonFire:     PUSH    R1
                MOV     R1, KEY_FIRE
                MOV     M[ ButtonKey ], R1
                POP     R1
                RTI

ButtonRight:    PUSH    R1
                MOV     R1, KEY_RIGHT
                MOV     M[ ButtonKey ], R1
                POP     R1
                RTI

;==============================================================================
; Rotinas utilitarias
;==============================================================================

;------------------------------------------------------------------------------
; ConfigureTimer: arma o temporizador para TICK_TIME x 100ms
;------------------------------------------------------------------------------
ConfigureTimer: PUSH    R1
                MOV     R1, TICK_TIME
                MOV     M[ TIMER_UNITS ], R1
                MOV     R1, ON
                MOV     M[ ACTIVATE_TIMER ], R1
                POP     R1
                RET

;------------------------------------------------------------------------------
; Random: gera um valor pseudo-aleatorio em M[Random_Var] (RandomV1 do exemplo)
;------------------------------------------------------------------------------
Random:         PUSH    R1
                MOV     R1, LSB_MASK
                AND     R1, M[ Random_Var ]
                BR.Z    RndRotate
                MOV     R1, RND_MASK
                XOR     M[ Random_Var ], R1
RndRotate:      ROR     M[ Random_Var ], 1
                POP     R1
                RET

;------------------------------------------------------------------------------
; WaitTicks: espera R1 interrupcoes do temporizador
; Entradas: R1 - numero de ticks
;------------------------------------------------------------------------------
WaitTicks:      PUSH    R1
                PUSH    R2
WtLoop:         CMP     R1, R0
                JMP.Z   WtEnd
WtPoll:         MOV     R2, M[ TimerFlag ]
                CMP     R2, OFF
                JMP.Z   WtPoll
                MOV     M[ TimerFlag ], R0
                DEC     R1
                JMP     WtLoop
WtEnd:          POP     R2
                POP     R1
                RET

;------------------------------------------------------------------------------
; WaitStart: espera ESPACO (ou botao I1). Enquanto espera, altera a semente
;            do gerador aleatorio, que depende assim do tempo de reacao.
;------------------------------------------------------------------------------
WaitStart:      PUSH    R1
                MOV     M[ ButtonKey ], R0
                MOV     R1, M[ IO_READ ]    ; descarta tecla pendente do jogo
WsLoop:         INC     M[ Random_Var ]
                MOV     R1, M[ ButtonKey ]
                CMP     R1, KEY_FIRE
                JMP.Z   WsDone
                MOV     R1, M[ IO_STATUS ]
                CMP     R1, OFF
                JMP.Z   WsLoop
                MOV     R1, M[ IO_READ ]
                CMP     R1, KEY_FIRE
                JMP.NZ  WsLoop
WsDone:         MOV     M[ ButtonKey ], R0
                MOV     M[ TimerFlag ], R0
                MOV     R1, M[ Random_Var ]
                CMP     R1, R0              ; semente 0 bloquearia o gerador
                JMP.NZ  WsEnd
                MOV     R1, RND_SEED
                MOV     M[ Random_Var ], R1
WsEnd:          POP     R1
                RET

;------------------------------------------------------------------------------
; ClearScreen: limpa a janela de texto (efeito da escrita de FFFFh no cursor)
;------------------------------------------------------------------------------
ClearScreen:    PUSH    R1
                MOV     R1, CURSOR_INIT
                MOV     M[ CURSOR ], R1
                POP     R1
                RET

;------------------------------------------------------------------------------
; PutChar: escreve um caracter na janela de texto
; Entradas: R1 - caracter, R2 - linha, R3 - coluna
;------------------------------------------------------------------------------
PutChar:        PUSH    R2
                SHL     R2, ROW_SHIFT
                OR      R2, R3
                MOV     M[ CURSOR ], R2
                MOV     M[ IO_WRITE ], R1
                POP     R2
                RET

;------------------------------------------------------------------------------
; PutSprite: escreve um sprite de SPRITE_WIDTH caracteres
; Entradas: R1 - endereco do sprite (0 = apagar), R2 - linha, R3 - coluna
;------------------------------------------------------------------------------
PutSprite:      PUSH    R1
                PUSH    R3
                PUSH    R4
                PUSH    R5
                MOV     R4, R1
                MOV     R5, SPRITE_WIDTH
PsLoop:         MOV     R1, BLANK
                CMP     R4, R0
                JMP.Z   PsPut
                MOV     R1, M[ R4 ]
                INC     R4
PsPut:          CALL    PutChar
                INC     R3
                DEC     R5
                JMP.NZ  PsLoop
                POP     R5
                POP     R4
                POP     R3
                POP     R1
                RET

;------------------------------------------------------------------------------
; PrintStr: escreve um texto terminado em FIM_TEXTO
; Entradas: R1 - endereco do texto, R2 - linha, R3 - coluna
;------------------------------------------------------------------------------
PrintStr:       PUSH    R1
                PUSH    R3
                PUSH    R4
                MOV     R4, R1
PrsLoop:        MOV     R1, M[ R4 ]
                CMP     R1, FIM_TEXTO
                JMP.Z   PrsEnd
                CALL    PutChar
                INC     R4
                INC     R3
                JMP     PrsLoop
PrsEnd:         POP     R4
                POP     R3
                POP     R1
                RET

;------------------------------------------------------------------------------
; PrintBlock: escreve um bloco de textos, cada um precedido da sua linha e
;             coluna e terminado em FIM_TEXTO; o bloco termina com TABLE_END
; Entradas: R1 - endereco do bloco
;------------------------------------------------------------------------------
PrintBlock:     PUSH    R1
                PUSH    R2
                PUSH    R3
                PUSH    R4
                MOV     R4, R1
PbLoop:         MOV     R2, M[ R4 ]
                CMP     R2, TABLE_END
                JMP.Z   PbEnd
                MOV     R3, M[ R4 + 1 ]
                ADD     R4, TEXT_HEADER
                MOV     R1, R4
                CALL    PrintStr
PbSkip:         MOV     R1, M[ R4 ]         ; avanca ate depois do FIM_TEXTO
                INC     R4
                CMP     R1, FIM_TEXTO
                JMP.NZ  PbSkip
                JMP     PbLoop
PbEnd:          POP     R4
                POP     R3
                POP     R2
                POP     R1
                RET

;------------------------------------------------------------------------------
; PrintNum: escreve um numero em decimal com zeros a esquerda
; Entradas: R1 - valor, R2 - linha, R3 - coluna, R4 - numero de digitos
;------------------------------------------------------------------------------
PrintNum:       PUSH    R1
                PUSH    R3
                PUSH    R4
                PUSH    R5
                ADD     R3, R4
                DEC     R3              ; comeca pelo digito mais a direita
PnLoop:         MOV     R5, DECIMAL_BASE
                DIV     R1, R5          ; R1 = quociente, R5 = resto
                PUSH    R1
                MOV     R1, R5
                ADD     R1, '0'
                CALL    PutChar
                POP     R1
                DEC     R3
                DEC     R4
                JMP.NZ  PnLoop
                POP     R5
                POP     R4
                POP     R3
                POP     R1
                RET

;------------------------------------------------------------------------------
; LcdPrint: escreve um texto no LCD
; Entradas: R1 - endereco do texto, R2 - palavra de controlo da posicao inicial
;------------------------------------------------------------------------------
LcdPrint:       PUSH    R1
                PUSH    R2
                PUSH    R3
LpLoop:         MOV     R3, M[ R1 ]
                CMP     R3, FIM_TEXTO
                JMP.Z   LpEnd
                MOV     M[ LCD_CTRL ], R2   ; a escrita nao avanca o cursor
                MOV     M[ LCD_WRITE ], R3
                INC     R1
                INC     R2
                JMP     LpLoop
LpEnd:          POP     R3
                POP     R2
                POP     R1
                RET

;==============================================================================
; Informacao do jogo (HUD e perifericos)
;==============================================================================

;------------------------------------------------------------------------------
; ShowScore: pontuacao na janela de texto e no display de 7 segmentos
;------------------------------------------------------------------------------
ShowScore:      PUSH    R1
                PUSH    R2
                PUSH    R3
                PUSH    R4
                MOV     R1, M[ Score ]
                MOV     R2, HUD_ROW
                MOV     R3, HUD_SCORE_VAL
                MOV     R4, SCORE_DIGITS
                CALL    PrintNum
                MOV     R2, DISP7_D0
                MOV     R4, DISP7_COUNT
Ss7Loop:        MOV     R3, DECIMAL_BASE
                DIV     R1, R3          ; R3 = digito
                MOV     M[ R2 ], R3
                INC     R2
                DEC     R4
                JMP.NZ  Ss7Loop
                POP     R4
                POP     R3
                POP     R2
                POP     R1
                RET

;------------------------------------------------------------------------------
; ShowLives: vidas na janela de texto e nos LEDs (um LED por vida)
;------------------------------------------------------------------------------
ShowLives:      PUSH    R1
                PUSH    R2
                PUSH    R3
                PUSH    R4
                MOV     R1, M[ Lives ]
                MOV     R2, HUD_ROW
                MOV     R3, HUD_LIVES_VAL
                MOV     R4, LIVES_DIGITS
                CALL    PrintNum
                MOV     R2, R0
SlLoop:         CMP     R1, R0
                JMP.Z   SlLeds
                SHL     R2, 1
                INC     R2
                DEC     R1
                JMP     SlLoop
SlLeds:         MOV     M[ LEDS ], R2
                POP     R4
                POP     R3
                POP     R2
                POP     R1
                RET

;------------------------------------------------------------------------------
; ShowWave: numero da onda na janela de texto e no LCD
;------------------------------------------------------------------------------
ShowWave:       PUSH    R1
                PUSH    R2
                PUSH    R3
                PUSH    R4
                MOV     R1, M[ Wave ]
                MOV     R2, HUD_ROW
                MOV     R3, HUD_WAVE_VAL
                MOV     R4, WAVE_DIGITS
                CALL    PrintNum
                MOV     R1, LCD_CLEAR
                MOV     M[ LCD_CTRL ], R1
                MOV     R1, StrLcdTitle
                MOV     R2, LCD_LINE0
                CALL    LcdPrint
                MOV     R1, StrLcdWave
                MOV     R2, LCD_LINE1
                CALL    LcdPrint
                MOV     R2, LCD_WAVE_POS
                MOV     R1, M[ Wave ]
                MOV     R4, WAVE_DIGITS
SwLoop:         MOV     R3, DECIMAL_BASE
                DIV     R1, R3              ; R3 = digito (unidades primeiro)
                ADD     R3, '0'
                MOV     M[ LCD_CTRL ], R2
                MOV     M[ LCD_WRITE ], R3
                DEC     R2
                DEC     R4
                JMP.NZ  SwLoop
                POP     R4
                POP     R3
                POP     R2
                POP     R1
                RET

;------------------------------------------------------------------------------
; DrawHUD: linha de informacao no topo da tela
;------------------------------------------------------------------------------
DrawHUD:        PUSH    R1
                PUSH    R2
                PUSH    R3
                MOV     R2, HUD_ROW
                MOV     R1, StrScore
                MOV     R3, HUD_SCORE_COL
                CALL    PrintStr
                MOV     R1, StrWave
                MOV     R3, HUD_WAVE_COL
                CALL    PrintStr
                MOV     R1, StrLives
                MOV     R3, HUD_LIVES_COL
                CALL    PrintStr
                CALL    ShowScore
                CALL    ShowWave
                CALL    ShowLives
                POP     R3
                POP     R2
                POP     R1
                RET

;------------------------------------------------------------------------------
; DrawGround: linha do chao
;------------------------------------------------------------------------------
DrawGround:     PUSH    R1
                PUSH    R2
                PUSH    R3
                MOV     R1, GROUND_CHAR
                MOV     R2, GROUND_ROW
                MOV     R3, LEFT_LIMIT
DgLoop:         CALL    PutChar
                INC     R3
                CMP     R3, RIGHT_LIMIT
                JMP.NP  DgLoop          ; ate coluna RIGHT_LIMIT inclusive
                POP     R3
                POP     R2
                POP     R1
                RET

;------------------------------------------------------------------------------
; DrawBunkers: desenha as celulas intactas das barreiras
;------------------------------------------------------------------------------
DrawBunkers:    PUSH    R1
                PUSH    R2
                PUSH    R3
                PUSH    R4
                PUSH    R5
                PUSH    R6
                MOV     R4, R0              ; indice da celula
                MOV     R5, BUNKER_COL0     ; coluna da barreira atual
                MOV     R6, BUNKER_COUNT
DbBunker:       MOV     R2, BUNKER_ROW
DbRow:          MOV     R3, R5
DbCell:         MOV     R1, M[ R4 + Bunker ]
                CMP     R1, OFF
                JMP.Z   DbSkip
                MOV     R1, BUNKER_CHAR
                CALL    PutChar
DbSkip:         INC     R4
                INC     R3
                MOV     R1, R3
                SUB     R1, R5
                CMP     R1, BUNKER_WIDTH
                JMP.NZ  DbCell
                INC     R2
                CMP     R2, BUNKER_END_ROW
                JMP.NZ  DbRow
                ADD     R5, BUNKER_STEP
                DEC     R6
                JMP.NZ  DbBunker
                POP     R6
                POP     R5
                POP     R4
                POP     R3
                POP     R2
                POP     R1
                RET

;------------------------------------------------------------------------------
; DrawPlayer / ErasePlayer
;------------------------------------------------------------------------------
DrawPlayer:     PUSH    R1
                MOV     R1, PlayerSprite
                CALL    RenderPlayer
                POP     R1
                RET

ErasePlayer:    PUSH    R1
                MOV     R1, R0
                CALL    RenderPlayer
                POP     R1
                RET

; Entradas: R1 - sprite (0 = apagar)
RenderPlayer:   PUSH    R2
                PUSH    R3
                MOV     R2, PLAYER_ROW
                MOV     R3, M[ PlayerCol ]
                CALL    PutSprite
                POP     R3
                POP     R2
                RET

;------------------------------------------------------------------------------
; RenderFormation: desenha ou apaga todos os aliens vivos
; Entradas: R1 - ON desenha, OFF apaga
;------------------------------------------------------------------------------
RenderFormation: PUSH   R1
                PUSH    R2
                PUSH    R3
                PUSH    R4
                PUSH    R5
                PUSH    R6
                PUSH    R7
                MOV     R7, R1              ; modo
                MOV     R4, R0              ; indice do alien
                MOV     R5, R0              ; linha da formacao
                MOV     R2, M[ FormRow ]
RfRow:          MOV     R3, M[ FormCol ]
                MOV     R6, ALIEN_COLS
RfCol:          MOV     R1, M[ R4 + AlienAlive ]
                CMP     R1, OFF
                JMP.Z   RfNext
                MOV     R1, R0
                CMP     R7, OFF
                JMP.Z   RfDraw
                MOV     R1, SpriteA
                ADD     R1, M[ R5 + RowSprite ]
                ADD     R1, M[ AnimFrame ]
RfDraw:         CALL    PutSprite
RfNext:         INC     R4
                ADD     R3, ALIEN_HSTEP
                DEC     R6
                JMP.NZ  RfCol
                ADD     R2, ALIEN_VSTEP
                INC     R5
                CMP     R5, ALIEN_ROWS
                JMP.NZ  RfRow
                POP     R7
                POP     R6
                POP     R5
                POP     R4
                POP     R3
                POP     R2
                POP     R1
                RET

;==============================================================================
; Inicializacao e telas
;==============================================================================

;------------------------------------------------------------------------------
; TitleScreen: tela de apresentacao; espera ESPACO
;------------------------------------------------------------------------------
TitleScreen:    PUSH    R1
                CALL    ClearScreen
                MOV     R1, TitleText
                CALL    PrintBlock
                MOV     R1, LCD_CLEAR
                MOV     M[ LCD_CTRL ], R1
                PUSH    R2
                MOV     R1, StrLcdTitle
                MOV     R2, LCD_LINE0
                CALL    LcdPrint
                POP     R2
                CALL    WaitStart
                POP     R1
                RET

;------------------------------------------------------------------------------
; InitGame: novo jogo
;------------------------------------------------------------------------------
InitGame:       PUSH    R1
                MOV     M[ Score ], R0
                MOV     R1, LIVES_INIT
                MOV     M[ Lives ], R1
                MOV     R1, FIRST_WAVE
                MOV     M[ Wave ], R1
                CALL    InitWave
                POP     R1
                RET

;------------------------------------------------------------------------------
; InitWave: prepara uma nova onda de aliens
;------------------------------------------------------------------------------
InitWave:       PUSH    R1
                PUSH    R2
                PUSH    R3
                CALL    ClearScreen
                MOV     R1, STATE_PLAYING
                MOV     M[ GameState ], R1
                MOV     M[ Paused ], R0
                MOV     R3, ON

                ; todos os aliens vivos
                MOV     R1, NUM_ALIENS
                MOV     M[ AliensLeft ], R1
                MOV     R2, R0
IwAlienLoop:    MOV     M[ R2 + AlienAlive ], R3
                INC     R2
                CMP     R2, NUM_ALIENS
                JMP.NZ  IwAlienLoop

                ; a cada onda a formacao comeca uma linha mais abaixo
                MOV     R1, M[ Wave ]
                ADD     R1, FORM_ROW0
                DEC     R1
                CMP     R1, FORM_ROW_MAX
                JMP.NP  IwRowOk
                MOV     R1, FORM_ROW_MAX
IwRowOk:        MOV     M[ FormRow ], R1
                MOV     R1, FORM_COL0
                MOV     M[ FormCol ], R1
                MOV     R1, DIR_RIGHT
                MOV     M[ FormDir ], R1
                MOV     M[ AnimFrame ], R0
                CALL    ComputeDelay

                ; barreiras intactas
                MOV     R2, R0
IwBunkerLoop:   MOV     M[ R2 + Bunker ], R3
                INC     R2
                CMP     R2, BUNKER_CELLS
                JMP.NZ  IwBunkerLoop

                ; sem tiros na tela
                MOV     M[ ShotActive ], R0
                MOV     R2, R0
IwBombLoop:     MOV     M[ R2 + BombActive ], R0
                INC     R2
                CMP     R2, MAX_BOMBS
                JMP.NZ  IwBombLoop

                MOV     R1, PLAYER_COL0
                MOV     M[ PlayerCol ], R1

                CALL    DrawHUD
                CALL    DrawGround
                CALL    DrawBunkers
                CALL    DrawPlayer
                MOV     R1, ON
                CALL    RenderFormation
                MOV     M[ TimerFlag ], R0
                POP     R3
                POP     R2
                POP     R1
                RET

;------------------------------------------------------------------------------
; ComputeDelay: quanto menos aliens, mais rapido a formacao anda
;------------------------------------------------------------------------------
ComputeDelay:   PUSH    R1
                MOV     R1, M[ AliensLeft ]
                SHR     R1, DELAY_SHIFT
                INC     R1
                MOV     M[ MoveCounter ], R1
                POP     R1
                RET

;------------------------------------------------------------------------------
; WaveDoneScreen: mensagem entre ondas
;------------------------------------------------------------------------------
WaveDoneScreen: PUSH    R1
                PUSH    R2
                PUSH    R3
                MOV     R1, StrWaveDone
                MOV     R2, MSG_ROW
                MOV     R3, MSG_COL
                CALL    PrintStr
                MOV     R1, WAVE_PAUSE
                CALL    WaitTicks
                POP     R3
                POP     R2
                POP     R1
                RET

;------------------------------------------------------------------------------
; GameOverScreen: mostra pontuacao e recorde; espera ESPACO
;------------------------------------------------------------------------------
GameOverScreen: PUSH    R1
                PUSH    R2
                PUSH    R3
                PUSH    R4
                ; atualiza recorde
                MOV     R1, M[ Score ]
                CMP     R1, M[ HighScore ]
                JMP.NP  GoNoRecord
                MOV     M[ HighScore ], R1
GoNoRecord:     MOV     R1, DEATH_PAUSE
                CALL    WaitTicks
                CALL    ClearScreen
                MOV     R1, GameOverText
                CALL    PrintBlock
                MOV     R1, M[ Score ]
                MOV     R2, FINAL_ROW
                MOV     R3, FINAL_VAL_COL
                MOV     R4, SCORE_DIGITS
                CALL    PrintNum
                MOV     R1, M[ HighScore ]
                MOV     R2, RECORD_ROW
                CALL    PrintNum
                MOV     R1, LCD_CLEAR
                MOV     M[ LCD_CTRL ], R1
                MOV     R1, StrLcdOver
                MOV     R2, LCD_LINE0
                CALL    LcdPrint
                CALL    WaitStart
                POP     R4
                POP     R3
                POP     R2
                POP     R1
                RET

;==============================================================================
; Entrada do jogador
;==============================================================================

;------------------------------------------------------------------------------
; ReadInput: le uma tecla (botoes da placa ou teclado), se houver
;------------------------------------------------------------------------------
ReadInput:      PUSH    R1
                MOV     R1, M[ ButtonKey ]
                CMP     R1, OFF
                JMP.Z   RiKeyboard
                MOV     M[ ButtonKey ], R0
                JMP     RiProcess
RiKeyboard:     MOV     R1, M[ IO_STATUS ]
                CMP     R1, OFF
                JMP.Z   RiEnd
                MOV     R1, M[ IO_READ ]
RiProcess:      CALL    ProcessKey
RiEnd:          POP     R1
                RET

;------------------------------------------------------------------------------
; ProcessKey: executa a acao de uma tecla
; Entradas: R1 - codigo ASCII da tecla
;------------------------------------------------------------------------------
ProcessKey:     PUSH    R1
                PUSH    R2
                OR      R1, CASE_MASK
                CMP     R1, KEY_PAUSE
                JMP.Z   PkPause
                MOV     R2, M[ Paused ]
                CMP     R2, OFF
                JMP.NZ  PkEnd
                CMP     R1, KEY_LEFT
                JMP.Z   PkLeft
                CMP     R1, KEY_RIGHT
                JMP.Z   PkRight
                CMP     R1, KEY_FIRE
                JMP.Z   PkFire
                JMP     PkEnd
PkLeft:         CALL    MoveLeft
                JMP     PkEnd
PkRight:        CALL    MoveRight
                JMP     PkEnd
PkFire:         CALL    FireShot
                JMP     PkEnd
PkPause:        CALL    TogglePause
PkEnd:          POP     R2
                POP     R1
                RET

;------------------------------------------------------------------------------
; TogglePause: pausa / continua o jogo
;------------------------------------------------------------------------------
TogglePause:    PUSH    R1
                PUSH    R2
                PUSH    R3
                MOV     R1, M[ Paused ]
                XOR     R1, ON
                MOV     M[ Paused ], R1
                MOV     R1, StrPause
                JMP.NZ  TpShow              ; flags do XOR
                MOV     R1, StrNoPause
TpShow:         MOV     R2, HUD_ROW
                MOV     R3, HUD_PAUSE_COL
                CALL    PrintStr
                POP     R3
                POP     R2
                POP     R1
                RET

;------------------------------------------------------------------------------
; MoveLeft / MoveRight: movem a nave PLAYER_STEP colunas
;------------------------------------------------------------------------------
MoveLeft:       PUSH    R1
                CALL    ErasePlayer
                MOV     R1, M[ PlayerCol ]
                SUB     R1, PLAYER_STEP
                CMP     R1, LEFT_LIMIT
                JMP.NN  MlOk
                MOV     R1, LEFT_LIMIT
MlOk:           MOV     M[ PlayerCol ], R1
                CALL    DrawPlayer
                POP     R1
                RET

MoveRight:      PUSH    R1
                CALL    ErasePlayer
                MOV     R1, M[ PlayerCol ]
                ADD     R1, PLAYER_STEP
                CMP     R1, PLAYER_MAX_COL
                JMP.NP  MrOk
                MOV     R1, PLAYER_MAX_COL
MrOk:           MOV     M[ PlayerCol ], R1
                CALL    DrawPlayer
                POP     R1
                RET

;------------------------------------------------------------------------------
; FireShot: dispara, se nao houver ja um tiro do jogador na tela
;------------------------------------------------------------------------------
FireShot:       PUSH    R1
                PUSH    R2
                PUSH    R3
                MOV     R1, M[ ShotActive ]
                CMP     R1, OFF
                JMP.NZ  FsEnd
                MOV     R1, ON
                MOV     M[ ShotActive ], R1
                MOV     R2, SHOT_START_ROW
                MOV     M[ ShotRow ], R2
                MOV     R3, M[ PlayerCol ]
                INC     R3                  ; centro da nave
                MOV     M[ ShotCol ], R3
                MOV     R1, SHOT_CHAR
                CALL    PutChar
FsEnd:          POP     R3
                POP     R2
                POP     R1
                RET

;==============================================================================
; Logica do jogo
;==============================================================================

;------------------------------------------------------------------------------
; GameTick: um passo do jogo (chamado a cada interrupcao do temporizador)
;------------------------------------------------------------------------------
GameTick:       PUSH    R1
                MOV     R1, M[ Paused ]
                CMP     R1, OFF
                JMP.NZ  GtEnd

                ; o tiro do jogador anda 2 linhas por tick
                CALL    UpdateShot
                CALL    UpdateShot
                MOV     R1, M[ AliensLeft ]
                CMP     R1, R0
                JMP.NZ  GtBombs
                MOV     R1, STATE_WAVE_DONE
                MOV     M[ GameState ], R1
                JMP     GtEnd

GtBombs:        CALL    UpdateBombs
                MOV     R1, M[ GameState ]
                CMP     R1, STATE_PLAYING
                JMP.NZ  GtEnd
                CALL    AlienFire

                DEC     M[ MoveCounter ]
                JMP.NZ  GtEnd
                CALL    MoveFormation
                CALL    ComputeDelay
GtEnd:          POP     R1
                RET

;------------------------------------------------------------------------------
; UpdateShot: move o tiro do jogador uma linha para cima e testa colisoes
;------------------------------------------------------------------------------
UpdateShot:     PUSH    R1
                PUSH    R2
                PUSH    R3
                MOV     R1, M[ ShotActive ]
                CMP     R1, OFF
                JMP.Z   UsEnd
                MOV     R2, M[ ShotRow ]
                MOV     R3, M[ ShotCol ]
                MOV     R1, BLANK
                CALL    PutChar             ; apaga posicao anterior
                DEC     R2
                CMP     R2, TOP_ROW
                JMP.N   UsKill
                MOV     M[ ShotRow ], R2
                CALL    CheckBunkerHit
                CMP     R1, OFF
                JMP.NZ  UsKill
                CALL    CheckAlienHit
                CMP     R1, OFF
                JMP.NZ  UsKill
                MOV     R1, SHOT_CHAR
                CALL    PutChar
                JMP     UsEnd
UsKill:         MOV     M[ ShotActive ], R0
UsEnd:          POP     R3
                POP     R2
                POP     R1
                RET

;------------------------------------------------------------------------------
; CheckBunkerHit: testa se a posicao atinge uma celula intacta de barreira;
;                 se sim, destroi a celula
; Entradas: R2 - linha, R3 - coluna
; Saidas:   R1 - ON se atingiu, OFF caso contrario
;------------------------------------------------------------------------------
CheckBunkerHit: PUSH    R4
                PUSH    R5
                PUSH    R6
                MOV     R1, OFF
                MOV     R4, R2
                SUB     R4, BUNKER_ROW      ; R4 = linha dentro da barreira
                JMP.N   CbhEnd
                CMP     R4, BUNKER_HEIGHT
                JMP.NN  CbhEnd
                MOV     R5, R3
                SUB     R5, BUNKER_COL0
                JMP.N   CbhEnd
                MOV     R6, BUNKER_STEP
                DIV     R5, R6              ; R5 = barreira, R6 = coluna nela
                CMP     R5, BUNKER_COUNT
                JMP.NN  CbhEnd
                CMP     R6, BUNKER_WIDTH
                JMP.NN  CbhEnd
                MOV     R1, BUNKER_SIZE
                MUL     R1, R5              ; R5 = barreira * BUNKER_SIZE
                MOV     R1, BUNKER_WIDTH
                MUL     R1, R4              ; R4 = linha * BUNKER_WIDTH
                ADD     R5, R4
                ADD     R5, R6              ; R5 = indice da celula
                MOV     R1, M[ R5 + Bunker ]
                CMP     R1, OFF
                JMP.Z   CbhEnd
                MOV     M[ R5 + Bunker ], R0
                MOV     R1, BLANK
                CALL    PutChar
                MOV     R1, ON
CbhEnd:         POP     R6
                POP     R5
                POP     R4
                RET

;------------------------------------------------------------------------------
; CheckAlienHit: testa se a posicao atinge um alien vivo; se sim, mata-o,
;                apaga-o e soma os pontos
; Entradas: R2 - linha, R3 - coluna
; Saidas:   R1 - ON se atingiu, OFF caso contrario
;------------------------------------------------------------------------------
CheckAlienHit:  PUSH    R3
                PUSH    R4
                PUSH    R5
                PUSH    R6
                PUSH    R7
                MOV     R1, OFF
                MOV     R4, R2
                SUB     R4, M[ FormRow ]
                JMP.N   CahEnd
                MOV     R5, ALIEN_VSTEP
                DIV     R4, R5              ; R4 = linha do alien, R5 = resto
                CMP     R5, R0
                JMP.NZ  CahEnd              ; linha entre aliens
                CMP     R4, ALIEN_ROWS
                JMP.NN  CahEnd
                MOV     R5, R3
                SUB     R5, M[ FormCol ]
                JMP.N   CahEnd
                MOV     R7, ALIEN_HSTEP
                DIV     R5, R7              ; R5 = coluna do alien, R7 = desvio
                CMP     R7, ALIEN_WIDTH
                JMP.NN  CahEnd              ; espaco entre aliens
                CMP     R5, ALIEN_COLS
                JMP.NN  CahEnd
                MOV     R1, R4
                MOV     R6, ALIEN_COLS
                MUL     R1, R6              ; R6 = linha * ALIEN_COLS
                ADD     R6, R5              ; R6 = indice do alien
                MOV     R1, M[ R6 + AlienAlive ]
                CMP     R1, OFF
                JMP.Z   CahEnd
                ; alien atingido
                MOV     M[ R6 + AlienAlive ], R0
                DEC     M[ AliensLeft ]
                MOV     R1, M[ R4 + AlienPoints ]
                ADD     M[ Score ], R1
                CALL    ShowScore
                MOV     R1, R0
                SUB     R3, R7              ; coluna inicial do sprite
                CALL    PutSprite           ; apaga o alien
                MOV     R1, ON
CahEnd:         POP     R7
                POP     R6
                POP     R5
                POP     R4
                POP     R3
                RET

;------------------------------------------------------------------------------
; CheckPlayerHit: testa se a posicao atinge a nave
; Entradas: R2 - linha, R3 - coluna
; Saidas:   R1 - ON se atingiu, OFF caso contrario
;------------------------------------------------------------------------------
CheckPlayerHit: PUSH    R4
                MOV     R1, OFF
                CMP     R2, PLAYER_ROW
                JMP.NZ  CphEnd
                MOV     R4, R3
                SUB     R4, M[ PlayerCol ]
                JMP.N   CphEnd
                CMP     R4, PLAYER_WIDTH
                JMP.NN  CphEnd
                MOV     R1, ON
CphEnd:         POP     R4
                RET

;------------------------------------------------------------------------------
; UpdateBombs: move as bombas dos aliens uma linha para baixo
;------------------------------------------------------------------------------
UpdateBombs:    PUSH    R1
                PUSH    R2
                PUSH    R3
                PUSH    R4
                MOV     R4, R0
UbLoop:         MOV     R1, M[ R4 + BombActive ]
                CMP     R1, OFF
                JMP.Z   UbNext
                MOV     R2, M[ R4 + BombRow ]
                MOV     R3, M[ R4 + BombCol ]
                MOV     R1, BLANK
                CALL    PutChar
                INC     R2
                CMP     R2, GROUND_ROW
                JMP.NN  UbKill
                MOV     M[ R4 + BombRow ], R2
                CALL    CheckBunkerHit
                CMP     R1, OFF
                JMP.NZ  UbKill
                CALL    CheckPlayerHit
                CMP     R1, OFF
                JMP.NZ  UbPlayerHit
                MOV     R1, BOMB_CHAR
                CALL    PutChar
                JMP     UbNext
UbPlayerHit:    CALL    PlayerDies
                JMP     UbEnd
UbKill:         MOV     M[ R4 + BombActive ], R0
UbNext:         INC     R4
                CMP     R4, MAX_BOMBS
                JMP.NZ  UbLoop
UbEnd:          POP     R4
                POP     R3
                POP     R2
                POP     R1
                RET

;------------------------------------------------------------------------------
; PlayerDies: nave atingida - perde uma vida
;------------------------------------------------------------------------------
PlayerDies:     PUSH    R1
                PUSH    R2
                PUSH    R3
                PUSH    R4
                ; apaga todas as bombas
                MOV     R4, R0
PdLoop:         MOV     R1, M[ R4 + BombActive ]
                CMP     R1, OFF
                JMP.Z   PdNext
                MOV     R2, M[ R4 + BombRow ]
                MOV     R3, M[ R4 + BombCol ]
                MOV     R1, BLANK
                CALL    PutChar
                MOV     M[ R4 + BombActive ], R0
PdNext:         INC     R4
                CMP     R4, MAX_BOMBS
                JMP.NZ  PdLoop
                ; explosao
                MOV     R1, ExplodeSprite
                CALL    RenderPlayer
                DEC     M[ Lives ]
                CALL    ShowLives
                MOV     R1, DEATH_PAUSE
                CALL    WaitTicks
                MOV     R1, M[ Lives ]
                CMP     R1, R0
                JMP.NZ  PdRespawn
                MOV     R1, STATE_GAMEOVER
                MOV     M[ GameState ], R1
                JMP     PdEnd
PdRespawn:      CALL    DrawPlayer
PdEnd:          POP     R4
                POP     R3
                POP     R2
                POP     R1
                RET

;------------------------------------------------------------------------------
; AlienFire: aleatoriamente, o alien mais baixo de uma coluna sorteada atira
;------------------------------------------------------------------------------
AlienFire:      PUSH    R1
                PUSH    R2
                PUSH    R4
                PUSH    R5
                PUSH    R6
                CALL    Random
                MOV     R1, M[ Random_Var ]
                AND     R1, FIRE_MASK
                JMP.NZ  AfEnd
                ; procura uma bomba livre
                MOV     R4, R0
AfSlot:         MOV     R1, M[ R4 + BombActive ]
                CMP     R1, OFF
                JMP.Z   AfColumn
                INC     R4
                CMP     R4, MAX_BOMBS
                JMP.NZ  AfSlot
                JMP     AfEnd
                ; sorteia a coluna
AfColumn:       CALL    Random
                MOV     R5, M[ Random_Var ]
                MOV     R6, ALIEN_COLS
                DIV     R5, R6              ; R6 = coluna sorteada
                MOV     R5, LAST_ROW_BASE
                ADD     R5, R6              ; comeca pela ultima linha
                MOV     R2, LAST_ALIEN_ROW
AfSearch:       MOV     R1, M[ R5 + AlienAlive ]
                CMP     R1, OFF
                JMP.NZ  AfShoot
                SUB     R5, ALIEN_COLS
                DEC     R2
                JMP.NN  AfSearch
                JMP     AfEnd               ; coluna vazia
AfShoot:        MOV     R1, ALIEN_VSTEP
                MUL     R1, R2              ; R2 = linha * ALIEN_VSTEP
                ADD     R2, M[ FormRow ]
                INC     R2                  ; logo abaixo do alien
                MOV     R1, ALIEN_HSTEP
                MUL     R1, R6              ; R6 = coluna * ALIEN_HSTEP
                ADD     R6, M[ FormCol ]
                INC     R6                  ; centro do alien
                MOV     M[ R4 + BombRow ], R2
                MOV     M[ R4 + BombCol ], R6
                MOV     R1, ON
                MOV     M[ R4 + BombActive ], R1
AfEnd:          POP     R6
                POP     R5
                POP     R4
                POP     R2
                POP     R1
                RET

;------------------------------------------------------------------------------
; ColumnBounds: colunas (0-10) do alien vivo mais a esquerda e mais a direita
; Saidas: R1 - coluna minima, R2 - coluna maxima
;------------------------------------------------------------------------------
ColumnBounds:   PUSH    R3
                PUSH    R4
                PUSH    R5
                MOV     R1, ALIEN_COLS
                MOV     R2, R0
                MOV     R3, R0              ; indice
                MOV     R4, R0              ; coluna
CbLoop:         MOV     R5, M[ R3 + AlienAlive ]
                CMP     R5, OFF
                JMP.Z   CbNext
                CMP     R4, R1
                JMP.NN  CbNoMin
                MOV     R1, R4
CbNoMin:        CMP     R4, R2
                JMP.N   CbNext
                MOV     R2, R4
CbNext:         INC     R3
                INC     R4
                CMP     R4, ALIEN_COLS
                JMP.NZ  CbSameRow
                MOV     R4, R0
CbSameRow:      CMP     R3, NUM_ALIENS
                JMP.NZ  CbLoop
                POP     R5
                POP     R4
                POP     R3
                RET

;------------------------------------------------------------------------------
; LowestAliveRow: linha (0-4) do alien vivo mais baixo
; Saidas: R1 - linha
;------------------------------------------------------------------------------
LowestAliveRow: PUSH    R2
                PUSH    R3
                MOV     R2, NUM_ALIENS
LarLoop:        DEC     R2
                JMP.N   LarNone
                MOV     R3, M[ R2 + AlienAlive ]
                CMP     R3, OFF
                JMP.Z   LarLoop
                MOV     R1, R2
                MOV     R3, ALIEN_COLS
                DIV     R1, R3              ; R1 = indice / ALIEN_COLS
                JMP     LarEnd
LarNone:        MOV     R1, R0
LarEnd:         POP     R3
                POP     R2
                RET

;------------------------------------------------------------------------------
; MoveFormation: anda a formacao um passo; ao bater na borda desce uma linha
;                e inverte o sentido. Testa a invasao.
;------------------------------------------------------------------------------
MoveFormation:  PUSH    R1
                PUSH    R2
                PUSH    R3
                PUSH    R4
                MOV     R1, OFF
                CALL    RenderFormation     ; apaga
                CALL    ColumnBounds
                MOV     R3, M[ FormDir ]
                CMP     R3, DIR_RIGHT
                JMP.Z   MfRight
                ; esquerda: primeira coluna ocupada - 1 < LEFT_LIMIT ?
                MOV     R4, ALIEN_HSTEP
                MUL     R4, R1              ; R1 = coluna minima * HSTEP
                ADD     R1, M[ FormCol ]
                DEC     R1
                CMP     R1, LEFT_LIMIT
                JMP.N   MfDescend
                DEC     M[ FormCol ]
                JMP     MfDone
                ; direita: ultima coluna ocupada + 1 > RIGHT_LIMIT ?
MfRight:        MOV     R4, ALIEN_HSTEP
                MUL     R4, R2              ; R2 = coluna maxima * HSTEP
                ADD     R2, M[ FormCol ]
                ADD     R2, ALIEN_WIDTH
                CMP     R2, RIGHT_LIMIT
                JMP.P   MfDescend
                INC     M[ FormCol ]
                JMP     MfDone
MfDescend:      INC     M[ FormRow ]
                NEG     R3
                MOV     M[ FormDir ], R3
MfDone:         MOV     R1, M[ AnimFrame ]
                XOR     R1, SPRITE_WIDTH
                MOV     M[ AnimFrame ], R1
                MOV     R1, ON
                CALL    RenderFormation     ; desenha na nova posicao
                ; invasao: o alien mais baixo chegou as barreiras?
                CALL    LowestAliveRow
                MOV     R2, ALIEN_VSTEP
                MUL     R2, R1              ; R1 = linha * VSTEP
                ADD     R1, M[ FormRow ]
                CMP     R1, INVASION_ROW
                JMP.N   MfEnd
                MOV     R1, STATE_GAMEOVER
                MOV     M[ GameState ], R1
MfEnd:          POP     R4
                POP     R3
                POP     R2
                POP     R1
                RET

;------------------------------------------------------------------------------
; Funcao Main
;------------------------------------------------------------------------------
                ;----------------------------------------------------------------
                ; Inicializacao de registradores / enderecos importantes do P3
                ; (este codigo tem que fazer parte de todos os arquivos assembly)
                ;----------------------------------------------------------------
Main:           MOV     R1, INITIAL_SP
                MOV     SP, R1              ; We need to initialize the stack
                MOV     R1, CURSOR_INIT     ; We need to initialize the cursor
                MOV     M[ CURSOR ], R1     ; with value CURSOR_INIT
                MOV     R1, INT_MASK        ; habilita temporizador e botoes
                MOV     M[ INT_MASK_ADDR ], R1
                ENI                         ; so depois de a pilha existir
                CALL    ConfigureTimer

                CALL    TitleScreen
NewGame:        CALL    InitGame

                ;--------------------------------------------------------------
                ; Ciclo principal: le o teclado continuamente e, a cada
                ; interrupcao do temporizador, avanca um passo do jogo
                ;--------------------------------------------------------------
GameLoop:       CALL    ReadInput
                MOV     R1, M[ TimerFlag ]
                CMP     R1, OFF
                JMP.Z   GameLoop
                MOV     M[ TimerFlag ], R0
                CALL    GameTick
                MOV     R1, M[ GameState ]
                CMP     R1, STATE_PLAYING
                JMP.Z   GameLoop
                CMP     R1, STATE_WAVE_DONE
                JMP.Z   NextWave
                CALL    GameOverScreen
                JMP     NewGame

NextWave:       CALL    WaveDoneScreen
                INC     M[ Wave ]
                CALL    InitWave
                JMP     GameLoop

Halt:           BR      Halt
