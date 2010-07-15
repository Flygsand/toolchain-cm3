/* The classic embedded version of "Hello World": A blinking LED */
#include <arm/NXP/LPC17xx/LPC17xx.h>

#define BV(x) (1<<(x))
#define BITBAND(addr,bit) (*((volatile unsigned long *)(((unsigned long)&(addr)-0x20000000)*32 + bit*4 + 0x22000000)))

int i;

int main(void) {
  LPC_GPIO1->FIODIR = BV(18) | BV(20) | BV(21) | BV(23);

  while (1) {
    BITBAND(LPC_GPIO1->FIOSET, 18) = 1;
    for (i=0;i<100000;i++)
      __NOP();
    BITBAND(LPC_GPIO1->FIOCLR, 18) = 1;
    for (i=0;i<100000;i++)
      __NOP();
  }
}
