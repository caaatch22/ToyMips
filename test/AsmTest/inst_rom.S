    .org 0x0
    .set noat
	.set noreorder
	.set nomacro
   .global _start
_start:
	addiu $s1,$zero,6      
	addiu $s2,$zero,5      
	addi $s1,$zero,3       	
	addi $s2,$zero,4       
	add $s3,$s1,$s2        
	sub $s3,$s2,$s1        
	and $s3,$s1,$s2        
	or $s3,$s1,$s2         
	ori $s3,$s1,5          
	xor  $s3,$s1,$s2 
	slt $s3,$s1,$s2 
	slt $s3,$s2,$s1 
	lui $s4,32768
	addiu $s1,$zero,3
	addiu $s2,$zero,4 
	addi $s1,$zero,5
	addi $s2,$zero,6 
	add $s3,$s1,$s2
	sub $s3,$s2,$s1 
	and $s3,$s1,$s2  
	or $s3,$s1,$s2 
	ori $s3,$s1,4
	xor  $s3,$s1,$s2 
	slt $s3,$s1,$s2 
	slt $s3,$s2,$s1 
	lui $s4,32768
	sw $s2,0($zero) 
	lw $s3,0($zero) 
	beq $s1,$s2,test1
	addi $s3,$zero,5
	beq $s1,$s3,test2
	test1:
	addiu $s3,$zero,7
	j end
	test2:
	addiu $s3,$zero,8
	j test1
	end:
