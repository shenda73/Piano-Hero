/*  
 *   Piano Hero
 *  Anthony Venen & Da Shen @ UIUC March 2016
 */

/*
 * AtMega2560 Datasheet
 * http://www.atmel.com/images/atmel-2549-8-bit-avr-microcontroller-atmega640-1280-1281-2560-2561_datasheet.pdf
 */

//Adjust this value to change the sensitivity of the piezos
const int PIEZO_THRESHOLD = 5;

// Pin Assignment
// LED Array - LEDs
const int LED_OCT1_DATA1 = 22;
const int LED_OCT1_DATA2 = 23;
const int LED_OCT2_DATA1 = 24;
const int LED_OCT3_DATA1 = 25;
const int LED_OCT3_DATA2 = 26;

const int PIEZO_C = 27;
const int PIEZO_B = 28;
const int PIEZO_A = 29;
const int PIEZO_OCT1_DATA_IN = 30;
const int PIEZO_OCT1_DATA_COMPARE = 31;
const int PIEZO_OCT2_DATA_IN = 32;
const int PIEZO_OCT2_DATA_COMPARE = 33;
const int PIEZO_OCT3_DATA_IN = 34;
const int PIEZO_OCT3_DATA_COMPARE = 35;

const int output_pins[] = {LED_OCT1_DATA1,LED_OCT1_DATA2,
    LED_OCT2_DATA1,LED_OCT2_DATA1,LED_OCT3_DATA2,PIEZO_C,PIEZO_B,
    PIEZO_A, PIEZO_OCT1_DATA_COMPARE, PIEZO_OCT2_DATA_COMPARE,
    PIEZO_OCT3_DATA_COMPARE};

const int input_pins[] = {PIEZO_OCT1_DATA_IN,PIEZO_OCT2_DATA_IN,
    PIEZO_OCT3_DATA_IN};


/* Clock References:
 * http://sphinx.mythic-beasts.com/~markt/ATmega-timers.html
 * 
 * Pins 4 and 13: controlled by timer0
 * Pins 11 and 12: controlled by timer1
 * Pins 9 and10: controlled by timer2
 * Pin 2, 3 and 5: controlled by timer 3
 * Pin 6, 7 and 8: controlled by timer 4
 * Pin 46, 45 and 44:: controlled by timer 5
 * 
 *  Note that
 * Timer/Counter0, Timer/Counter1, Timer/Counter3, Timer/Counter4 
 * and Timer/Counter5 share the same prescaler
 * and a reset of this prescaler will affect all timers.
*/

// Clock Signals
const int CLK_8MHZ = 44;
const int CLK_1MHZ = 10;

// Initialize 8MHz and 1Mhz Clock Signal
void CLK_init() {
  // Reference:
  // https://www.arduino.cc/en/Tutorial/SecretsOfArduinoPWM
  // http://playground.arduino.cc/Main/TimerPWMCheatsheet
  // http://blog.oscarliang.net/arduino-timer-and-interrupt-tutorial/
  // http://sphinx.mythic-beasts.com/~markt/ATmega-timers.html
  // http://forum.arduino.cc/index.php?topic=62964.0
  pinMode(CLK_8MHZ, OUTPUT);
  TCCR5A = _BV(COM5A1) | _BV(WGM51) | _BV(WGM50);
  // set the prescale factor to 1
  TCCR5B = _BV(CS50);
  // set duty cycle to 50%
  OCR5AH = 0;
  OCR5AL = 255;
  
  pinMode(CLK_1MHZ, OUTPUT);
  TCCR2A = _BV(COM2A1) | _BV(WGM21) | _BV(WGM20);
  TCCR2B = _BV(CS20);
  // set duty cycle to 50%
  OCR2A = 127;
  
}







void setup() {
  // assign output pins
  for(int i = 0; i < sizeof(output_pins);i++){
    pinMode(output_pins[i], OUTPUT);
  }
  // assign input pins
  for(int i = 0; i < sizeof(input_pins);i++){
    pinMode(input_pins[i], INPUT);
  }
  CLK_init();
  
}

void loop() {
  // put your main code here, to run repeatedly:
  analogWrite(7,10);
}
