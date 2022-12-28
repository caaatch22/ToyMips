   .org 0x0
   .set noat
   .set noreorder
   .set nomacro
   .global _start
_start:
   ori  $1,$0,0x0001   # $1 = 0x1                1   
   j    0x20
   ori  $1,$0,0x0002   # $1 = 0x2
   ori  $1,$0,0x1111
   ori  $1,$0,0x1100

   .org 0x20
   ori  $1,$0,0x0003   # $1 = 0x3                 2        
   jal  0x40           # $31 = 0x2c               3
   div  $zero,$31,$1   # $1 = 0x3                
                       # HI = 0x2, LO = 0xe       5
   ori  $1,$0,0x0005   # r1 = 0x5
   ori  $1,$0,0x0006   # r1 = 0x6
   j    0x60
   nop

   .org 0x40
               
   jalr $2,$31          # $2 = 0x48                4
   or   $1,$2,$0        # $1 = 0x48
   ori  $1,$0,0x0009    # $1 = 0x9                 7
   ori  $1,$0,0x000a    # $1 = 0xa                 8
   j 0x80
   nop

   .org 0x60
   ori  $1,$0,0x0007    # $1 = 0x7                 6           
   jr   $2           
   ori  $1,$0,0x0008    # $1 = 0x8
   ori  $1,$0,0x1111
   ori  $1,$0,0x1100

   .org 0x80
   nop
    
_loop:
   j _loop
   nop
