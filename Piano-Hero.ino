/*  
 *   Piano Hero
 *  Anthony Venen & Da Shen @ UIUC March 2016
 */
#define DEBUG_MODE 0
/*
 * AtMega2560 Datasheet
 * http://www.atmel.com/images/atmel-2549-8-bit-avr-microcontroller-atmega640-1280-1281-2560-2561_datasheet.pdf
 * https://arduino-info.wikispaces.com/MegaQuickRef
 */


//Adjust this value to change the sensitivity of the piezos
const int PIEZO_THRESHOLD = 5;

// Pin Assignment
// LED Array - LEDs
const int LED_DATA1 = 22;
const int LED_DATA2 = 23;
const int LED_DATA3 = 24;
const int LED_DATA4 = 25;
const int LED_DATA5 = 26;

const int PIEZO_C = 27;
const int PIEZO_B = 28;
const int PIEZO_A = 29;
const int PIEZO_DATA_IN1 = 30;
const int PIEZO_DATA_IN2 = 31;
const int PIEZO_DATA_IN3 = 32;
const int PIEZO_DATA_IN4 = 33;
const int PIEZO_DATA_IN5 = 34;

const int PIEZO_DATA_COMPARE1 = 35;
const int PIEZO_DATA_COMPARE2 = 36;
const int PIEZO_DATA_COMPARE3 = 37;
const int PIEZO_DATA_COMPARE4 = 38;
const int PIEZO_DATA_COMPARE5 = 39;

static int SLOW_SRCLK = 40;
static int SLOW_RCLK = 41;
static int FAST_SRCLK = 42;
static int FAST_RCLK = 43;

const int output_pins[] = {LED_DATA1,LED_DATA2,LED_DATA3,
LED_DATA4,LED_DATA5,PIEZO_C,PIEZO_B,PIEZO_A,PIEZO_DATA_COMPARE1,
PIEZO_DATA_COMPARE2,PIEZO_DATA_COMPARE3,PIEZO_DATA_COMPARE4,
PIEZO_DATA_COMPARE5,SLOW_SRCLK,SLOW_RCLK,FAST_SRCLK,FAST_RCLK};

const int input_pins[] = {PIEZO_DATA_IN1,PIEZO_DATA_IN2,
    PIEZO_DATA_IN3,PIEZO_DATA_IN4,PIEZO_DATA_IN5};


/*
 * ================ HELPER FUNCTIONS ================ 
 * 
 */
 

void light_up_LED_column(int col_num) {
   
}



void piezo_loop() {
  
}



/*
 * =============== MAIN FUNCTION LOOP ==============
 */

static int slow_clk_freq = 1; // Hz
static int fast_clk_freq = 8; // Hz

// this function simulates a full cycle of the slow clock
// note: columns_to_light, e.g. 10000110, which lights up 1st,6th,
// and 7th lights
void clk_function(float slow_freq, char* columns_to_light,int LED_data_pin){
  int delay_time = 1000/slow_freq/2/8;
  boolean turn_off_light = false;
  
  // slow clock - goes up
  digitalWrite(SLOW_SRCLK, HIGH);
  digitalWrite(SLOW_RCLK, LOW);

  //fast clock - up/down for 4 times
  int i = 0;
  for(i = 0; i < 4; i++) {
    if(columns_to_light[7-i] == '1') {
      turn_off_light = true;
    }
    if(turn_off_light) {
//      delay(3);
      digitalWrite(LED_data_pin,HIGH);
//      delay(3);
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
//    Serial.println(columns_to_light[7-i]);
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

void set_column_light_byte(byte *target, int8_t num) {
  if (num <= 8 and num >= 1) {
    (*target) = *target & (0x01 << num);
  }
}

void setup() {
  if(DEBUG_MODE){
    Serial.begin(9600);
  }
//  Serial.print(sizeof(output_pins)/sizeof(int));
  int8_t num_outputs = sizeof(output_pins)/sizeof(int);
  int8_t num_inputs = sizeof(input_pins)/sizeof(int);
  // init output pins
  for(int i = 0; i < num_outputs;i++){
    pinMode(output_pins[i], OUTPUT);
  }
  // init input pins
  for(int i = 0; i < num_inputs;i++){
    pinMode(input_pins[i], INPUT);
  }

  pinMode(13,OUTPUT);
}

void loop() {
  char data[] = "00000001";
  clk_function(1,data,LED_DATA1);
//  analogWrite(LED_DATA1,100);
}
