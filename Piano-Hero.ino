/*  
 *   Piano Hero
 *  Anthony Venen & Da Shen @ UIUC March 2016
 */
 
#include <PinChangeInt.h>
 
#define DEBUG_MODE 1

#define BLEmini Serial1
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

// BT state
// 0 - wait for init, 1 - wait for value, 
static int8_t BT_state = 0; 
volatile static byte incomingByte = 0;
static int count = 0;

// Bluetooth Protocol
//Arduino -> iPhone
#define RESP_ACKNOWLEDGE 0xE5
#define RESP_DECLINE 0x1A
#define RESP_TEMP_ADJUST_FAST 0xA1
#define RESP_TEMP_ADJUST_DOWN 0xA0
//Arduino <- iPhone
#define FUNC_START_PLAYING 0x97
#define FUNC_STOP_PLAYING 0x98
#define FUNC_START_OF_DATA_TRANSMISSION 0x99
#define FUNC_END_OF_DATA_TRANSMISSION 0x9A
#define FUNC_CLR_SCREEN 0x99
#define FUNC_TEMP_ADJUST_FAST 0x91
#define FUNC_TEMP_ADJUST_DOWN 0x90




// -------- test ---------
//triggered values
volatile int trigger_value[5][8] = {{0},{0},{0},{0},{0}};

static int current_column = 0;

/*
 * ================ HELPER FUNCTIONS ================ 
 * 
 */

// adapted from:
// http://ericjknapp.com/blog/2014/04/13/midi-notes/
const char * noteForMidiNumber(int midiNumber) {
  const char * const noteArraySharps[] = {"", "", "", "", "", "", "", "", "", "", "", "",
    "C0", "C#0", "D0", "D#0", "E0", "F0", "F#0", "G0", "G#0", "A0", "A#0", "B0",
    "C1", "C#1", "D1", "D#1", "E1", "F1", "F#1", "G1", "G#1", "A1", "A#1", "B1",
    "C2", "C#2", "D2", "D#2", "E2", "F2", "F#2", "G2", "G#2", "A2", "A#2", "B2",
    "C3", "C#3", "D3", "D#3", "E3", "F3", "F#3", "G3", "G#3", "A3", "A#3", "B3",
    "C4", "C#4", "D4", "D#4", "E4", "F4", "F#4", "G4", "G#4", "A4", "A#4", "B4",
    "C5", "C#5", "D5", "D#5", "E5", "F5", "F#5", "G5", "G#5", "A5", "A#5", "B5",
    "C6", "C#6", "D6", "D#6", "E6", "F6", "F#6", "G6", "G#6", "A6", "A#6", "B6",
    "C7", "C#7", "D7", "D#7", "E7", "F7", "F#7", "G7", "G#7", "A7", "A#7", "B7",
    "C8", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""};
  return noteArraySharps[midiNumber];
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

  BLEmini.begin(57600);

  // CLR bit shifter
  if (clear_bit_shifter) {
    digitalWrite(SLOW_SRCLR,LOW);
    digitalWrite(FAST_SRCLR,LOW);
    clear_bit_shifter = false;
  }
  
}


// CLK state
// 0 - stopped
// 1 - SLOW_SRCLK up, SLOW_RCLK down, FAST_SRCLK up, FAST_RCLK down
// 2 - FAST_SRCLK down, FAST_RCLK up
// 3 - FAST_SRCLK up, FAST_RCLK down 
// 4 - FAST_SRCLK down, FAST_RCLK up
// 5 - FAST_SRCLK up, FAST_RCLK down 
// 6 - FAST_SRCLK down, FAST_RCLK up
// 7 - FAST_SRCLK up, FAST_RCLK down 
// 8 - FAST_SRCLK down, FAST_RCLK up, SLOW_SRCLK down, SLOW_RCLK up
// 9 - FAST_SRCLK up, FAST_RCLK down
// 10 - FAST_SRCLK down, FAST_RCLK up
// 11 - FAST_SRCLK up, FAST_RCLK down
// 12 - FAST_SRCLK down, FAST_RCLK up
// 13 - FAST_SRCLK up, FAST_RCLK down
// 14 - FAST_SRCLK down, FAST_RCLK up
// 15 - FAST_SRCLK up, FAST_RCLK down
// 16 - FAST_SRCLK down, FAST_RCLK up
//  --- set CLK frequency here ---
static int slow_freq = 1; // the slow clock runs at 1Hz
static unsigned int CLK_state = 0;
static int delay_time = 1000/slow_freq/2/8;
static bool start_clk_flag = false;
unsigned long previousMillis = 0;
volatile char LED_data[5] = {0b01000001,0b00000000,0b00000000,0b00000000,0b00000000};
bool dim_light[5] = {false};
const int8_t LED_data_pin[5] = {LED_DATA1,LED_DATA2,LED_DATA3,LED_DATA4,LED_DATA5};

void CLK_GEN_helper() {
  // clock logic
  if (CLK_state > 16) return;
  if (CLK_state == 1){
    digitalWrite(SLOW_SRCLK, HIGH);
    digitalWrite(SLOW_RCLK, LOW);
  } else if (CLK_state == 8){
    digitalWrite(SLOW_SRCLK, LOW);
    digitalWrite(SLOW_RCLK, HIGH);
  }
  if(CLK_state % 2 != 0){
    digitalWrite(FAST_SRCLK, HIGH);
    digitalWrite(FAST_RCLK, LOW);
    if(start_clk_flag){
      for(int i = 0; i < 5; i++){
        if((LED_data[i] >> (7-(CLK_state-1)/2)) & (0x1) == 1){
          Serial.print(CLK_state);
          Serial.print("  light up!! ");
          Serial.println(LED_data_pin[i]);
          dim_light[i] = true;
          digitalWrite(LED_data_pin[i],HIGH);
        }
      }
    }
  } else {
    digitalWrite(FAST_SRCLK, LOW);
    digitalWrite(FAST_RCLK, HIGH); 
    if(start_clk_flag){
      for(int i = 0; i < 5; i++){
        if(dim_light[i]){
          Serial.print(CLK_state);
          Serial.print("  dim down!! ");
          Serial.println(LED_data_pin[i]);
          dim_light[i] = false;
          digitalWrite(LED_data_pin[i],LOW);
        }
      } 
    }
  }
  
  previousMillis = millis();
  CLK_state *= 100;
}

// Synchronous Clock Generator
void CLK_GEN() {
  if (CLK_state == 0){
    if(start_clk_flag){
        CLK_state = 1;
    }
  } else if (CLK_state > 16) {
    unsigned long currentMillis = millis();
    if(currentMillis - previousMillis >= delay_time){
      CLK_state = CLK_state/100 + 1;
      if(CLK_state == 17) CLK_state = 1;
    }
  } else {
    CLK_GEN_helper();
  }
}

void clear_screen(bool clearScr) {
  if(clearScr){
    digitalWrite(SLOW_SRCLR,LOW);
    digitalWrite(FAST_SRCLR,LOW);  
  } else {
    digitalWrite(SLOW_SRCLR,HIGH);
    digitalWrite(FAST_SRCLR,HIGH);
  }
}

struct MIDINote {
  uint32_t timeStampIncrement;
  uint8_t note;
  uint8_t turnOnNote; // 1 - turn on, 2 - turn off
};





void BTHandler() {
  switch (incomingByte) {
    case FUNC_START_PLAYING:
      start_clk_flag = true;
      break;
    case FUNC_STOP_PLAYING:
      start_clk_flag = false;
      break;
    case FUNC_START_OF_DATA_TRANSMISSION:
      Serial.println("BT state 1");
      BT_state = 1;
      break;
    case FUNC_END_OF_DATA_TRANSMISSION:
      Serial.println("BT state 0");
      BT_state = 0;
      break;
    default:
      Serial.println(incomingByte, HEX);
      count++;
    break;
  }

//  BLEmini.write(RESP_ACKNOWLEDGE);
}

void loop() {
  
  // Background process
  CLK_GEN();
  
  // when Bluetooth Data comes in
  if(BLEmini.available() > 0) {
    incomingByte = BLEmini.read();
//    Serial.println( incomingByte, HEX );
    BTHandler();
  }
}

//void loop() {
////  if(!clear_bit_shifter) {
////    digitalWrite(SLOW_SRCLR,HIGH);
////    digitalWrite(FAST_SRCLR,HIGH);
////    clear_bit_shifter = true;
////  } 
//  
////  char data[] = "00000111";
////  LED_array_clk_gen(1,data,LED_DATA1);
//
//  // when Bluetooth Data comes in
//  if(Serial1.available() > 0) {
//    Serial.write( Serial1.read() );
//    
//  }
//
//  
//}
