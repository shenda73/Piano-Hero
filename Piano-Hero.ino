/*  
 *   Piano Hero
 *  Anthony Venen & Da Shen @ UIUC March 2016
 */
 
#include <PinChangeInt.h>
 
#define DEBUG_MODE 1
/*
 * 
 * AtMega2560 Datasheet
 * http://www.atmel.com/images/atmel-2549-8-bit-avr-microcontroller-atmega640-1280-1281-2560-2561_datasheet.pdf
 * https://arduino-info.wikispaces.com/MegaQuickRef
 */


//Adjust this value to change the sensitivity of the piezos
const int PIEZO_THRESHOLD = 5;

// Pin Assignment
// LED Array - LEDs
const int8_t LED_DATA1 = 22;
const int8_t LED_DATA2 = 23;
const int8_t LED_DATA3 = 24;
const int8_t LED_DATA4 = 25;
const int8_t LED_DATA5 = 26;

const int8_t PIEZO_C = 27;
const int8_t PIEZO_B = 28;
const int8_t PIEZO_A = 29;
const int8_t PIEZO_DATA_IN1 = A15;
const int8_t PIEZO_DATA_IN2 = A14;
const int8_t PIEZO_DATA_IN3 = A13;
const int8_t PIEZO_DATA_IN4 = A12;
const int8_t PIEZO_DATA_IN5 = A11;

const int8_t PIEZO_DATA_COMPARE1 = 30;
const int8_t PIEZO_DATA_COMPARE2 = 31;
const int8_t PIEZO_DATA_COMPARE3 = 32;
const int8_t PIEZO_DATA_COMPARE4 = 33;
const int8_t PIEZO_DATA_COMPARE5 = 34;

static int8_t SLOW_SRCLK = 40;
static int8_t SLOW_RCLK = 41;
static int8_t SLOW_SRCLR = 42;
static int8_t FAST_SRCLK = 43;
static int8_t FAST_RCLK = 44;
static int8_t FAST_SRCLR = 45;

const int8_t output_pins[] = {LED_DATA1,LED_DATA2,LED_DATA3,
LED_DATA4,LED_DATA5,PIEZO_C,PIEZO_B,PIEZO_A,PIEZO_DATA_COMPARE1,
PIEZO_DATA_COMPARE2,PIEZO_DATA_COMPARE3,PIEZO_DATA_COMPARE4,
PIEZO_DATA_COMPARE5,SLOW_SRCLK,SLOW_RCLK,SLOW_SRCLR,FAST_SRCLK,
FAST_RCLK,FAST_SRCLR};

const int8_t input_pins[] = {PIEZO_DATA_IN1,PIEZO_DATA_IN2,
    PIEZO_DATA_IN3,PIEZO_DATA_IN4,PIEZO_DATA_IN5};

// frequency
static int slow_clk_freq = 1; // Hz
static int fast_clk_freq = 8; // Hz


// -------- test ---------
//triggered values
volatile int trigger_value[5][8] = {{0},{0},{0},{0},{0}};

static int current_column = 0;

/*
 * ================ HELPER FUNCTIONS ================ 
 * 
 */

void clk_gen_test() {
//  pinMode(9,OUTPUT);
//  pinMode(10,OUTPUT);
//  TCCR2A = ;
//  TCCR2B = ;
  return;
}

void light_up_LED_column(int col_num) {
   
}

void piezo_interrupt_handler(){
  piezo_loop(input_pins);
}

void piezo_loop(const int8_t piezo_data_pins[]) {
  for(int i = 0;i< 8;i++){
    digitalWrite(PIEZO_C, (i >> 2) & 0x01);
    digitalWrite(PIEZO_B, (i >> 1) & 0x01);
    digitalWrite(PIEZO_A, i & 0x01);
//    Serial.print("cur num: ");
//    Serial.println(i);
//    Serial.println(C);
//    Serial.println(B);
//    Serial.println(A);
    for(int j = 0;j<5;j++){
      trigger_value[j][i] = analogRead(piezo_data_pins[j]);
      if(trigger_value[j][i] > PIEZO_THRESHOLD) {
//        Serial.print("knock detected: key");
//        Serial.println(j*8+i+1);
        // should let other program do things
      }
    }
  }
}



// TODO: convert this to millis() based background 
// reference: 
// https://www.baldengineer.com/millis-tutorial.html

// this function simulates a full cycle of the slow clock
// note: columns_to_light, e.g. 10000110, which lights up 1st,6th,
// and 7th lights
// Example:
//  char data[] = "00000001";
//  LED_array_clk_gen(1,data,LED_DATA1);
void LED_array_clk_gen(float slow_freq, char* columns_to_light,int LED_data_pin){
  int delay_time = 1000/slow_freq/2/8;
  boolean turn_off_light = false;

  current_column = 0;
  // slow clock - goes up
  digitalWrite(SLOW_SRCLK, HIGH);
  digitalWrite(SLOW_RCLK, LOW);

  //fast clock - up/down for 4 times
  int i = 0;
  for(i = 0; i < 4; i++) {
    current_column++;
    if(columns_to_light[7-i] == '1') {
      turn_off_light = true;
    }
    if(turn_off_light) {
      digitalWrite(LED_data_pin,HIGH);
    }
    digitalWrite(FAST_SRCLK, HIGH);
    digitalWrite(FAST_RCLK, LOW);
    delay(delay_time);
    digitalWrite(FAST_SRCLK, LOW);
    digitalWrite(FAST_RCLK, HIGH);
    if(turn_off_light) {
      turn_off_light = false;
      digitalWrite(LED_data_pin,LOW);
    }
    delay(delay_time);
  }

  // slow clock - goes down
  digitalWrite(SLOW_SRCLK, LOW);
  digitalWrite(SLOW_RCLK, HIGH);

  //fast clock - up/down for 4 times
  for(; i < 8; i++) {
    current_column++;
    if(columns_to_light[7-i] == '1') {
      turn_off_light = true;
    }
    if(turn_off_light) {
      digitalWrite(LED_data_pin,HIGH);
    }
    digitalWrite(FAST_SRCLK, HIGH);
    digitalWrite(FAST_RCLK, LOW);
    delay(delay_time);
    digitalWrite(FAST_SRCLK, LOW);
    digitalWrite(FAST_RCLK, HIGH);
    if(turn_off_light) {
      turn_off_light = false;
      digitalWrite(LED_data_pin,LOW);
    }
    delay(delay_time);
  }
  
}



/*
 * =============== MAIN FUNCTION LOOP ==============
 */
static bool clear_bit_shifter = true;

void setup() {
  if(DEBUG_MODE){
    Serial.begin(57600);
    Serial.println("Setup Arduino...");
  }
  
//  Serial.print(sizeof(output_pins)/sizeof(int));
  int8_t num_outputs = sizeof(output_pins);
  int8_t num_inputs = sizeof(input_pins);
  // init output pins
  Serial.print("init output pins: ");
  for(int i = 0; i < num_outputs;i++){
    pinMode(output_pins[i], OUTPUT);
    Serial.print(" ");
    Serial.print(output_pins[i]);
  }
  // init input pins (as interrupts)
  Serial.println("");
  Serial.print("init input pins: ");
  for(int i = 0; i < num_inputs;i++){
    pinMode(input_pins[i], INPUT_PULLUP);
    Serial.print(" ");
    Serial.print(input_pins[i]);
    attachPinChangeInterrupt(input_pins[i],piezo_interrupt_handler,RISING);
  }

//  pinMode(13,OUTPUT);
  Serial1.begin(57600);

  // CLR bit shifter
  if (clear_bit_shifter) {
    digitalWrite(SLOW_SRCLR,LOW);
    digitalWrite(FAST_SRCLR,LOW);
    clear_bit_shifter = false;
  }
  
}

unsigned char buf[16] = {0};
unsigned char len = 0;

void loop() {
//  if(!clear_bit_shifter) {
//    digitalWrite(SLOW_SRCLR,HIGH);
//    digitalWrite(FAST_SRCLR,HIGH);
//    clear_bit_shifter = true;
//  } 
  
  char data[] = "00000111";
  LED_array_clk_gen(1,data,LED_DATA1);

  // when Bluetooth Data comes in
  if(Serial1.available() > 0) {
    Serial.write( Serial1.read() );
    
  }
//  while ( Serial.available() )
//  {
//    unsigned char c = Serial.read();
//    if (c != 0x0A)
//    {
//      if (len < 16)
//        buf[len++] = c;
//    }
//    else
//    {
//      buf[len++] = 0x0A;
//      
//      for (int i = 0; i < len; i++)
//         Serial1.write(buf[i]);
//      len = 0;
//    }
//  }
  
}
