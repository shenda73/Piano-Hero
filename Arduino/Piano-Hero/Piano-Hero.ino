/*  
 *   Piano Hero
 *
 *  Anthony Venen & Da Shen @ UIUC March 2016
 */
 
/*
 * AtMega2560 Datasheet
 * http://www.atmel.com/images/atmel-2549-8-bit-avr-microcontroller-atmega640-1280-1281-2560-2561_datasheet.pdf
 * https://arduino-info.wikispaces.com/MegaQuickRef
 * 
 */

#include <PinChangeInt.h>
#include <LiquidCrystal.h>

typedef uint8_t MIDIEvent;

static bool ran_once_flag = false;

#define DEBUG_MODE 1
#define BLEmini Serial1
#define MAX_MIDI_EVENTS 4500

//  Bluetooth Protocol 
//Arduino -> iPhone
#define RESP_ACKNOWLEDGE 0xE5
#define RESP_DECLINE 0xE6
#define RESP_START_CONNECTION 0xE7
#define RESP_END_CONNECTION 0xE8
#define RESP_START_PLAYBACK 0xE9
#define RESP_END_PLAYBACK 0xEA
#define RESP_TOGGLE_METRONOME 0xEB

#define RESP_TEMP_ADJUST_FAST 0xA1
#define RESP_TEMP_ADJUST_DOWN 0xA0

//Arduino <- iPhone
#define FUNC_START_LOADING 0x97
#define FUNC_STOP_LOADING 0x98
#define FUNC_START_OF_DATA_TRANSMISSION 0x99
#define FUNC_END_OF_DATA_TRANSMISSION 0x9A
#define FUNC_START_PLAYBACK 0x9B
#define FUNC_PAUSE_PLAYBACK 0x9C
#define FUNC_TOGGLE_METRONOME 0x9D
#define FUNC_METRONOME_VOL_UP 0x9E
#define FUNC_METRONOME_VOL_DOWN 0x9F
#define FUNC_CLR_SCREEN 0xAF
#define FUNC_TEMP_ADJUST_UP 0x91
#define FUNC_TEMP_ADJUST_DOWN 0x90

// internal use
#define END_OF_MIDI_STREAM 0x8B

// Time Markers
unsigned long previous_millis_CLK = 0;
unsigned long previous_millis_MIDI = 0;
unsigned long previous_millis_metronome = 0;
unsigned long curEventInterval_MIDI = 0;

//Adjust this value to change the sensitivity of the piezos
const int PIEZO_THRESHOLD = 55;

//  =============== Pin Assignment ===============
// LED Array - LEDs
const int8_t METRONOME =  13;
const int8_t SCREEN_DATA0 = 30;
const int8_t SCREEN_DATA1 = 31;
const int8_t SCREEN_DATA2 = 32;
const int8_t SCREEN_DATA3 = 33;
const int8_t SCREEN_DATA4 = 34;
const int8_t SCREEN_DATA5 = 35;
const int8_t SCREEN_DATA6 = 36;
const int8_t SCREEN_DATA7 = 37;
const int8_t SCREEN_EN = 38;
const int8_t SCREEN_RW = 39;
const int8_t SCREEN_RS = 46;

const int8_t LED_DATA1 = 22;
const int8_t LED_DATA2 = 23;
const int8_t LED_DATA3 = 24;
const int8_t LED_DATA4 = 25;
const int8_t LED_DATA5 = 26;

const int8_t PIEZO_C = 27;
const int8_t PIEZO_B = 28;
const int8_t PIEZO_A = 29;

const int8_t SLOW_SRCLK = 40;
const int8_t SLOW_RCLK = 41;
const int8_t SLOW_SRCLR = 42;  // set high by defualt
const int8_t FAST_SRCLK = 43;
const int8_t FAST_RCLK = 44;
const int8_t FAST_SRCLR = 45;  // set high by default

// Interrup pins
const int8_t ROTARY_A = 47;
const int8_t ROTARY_B = 48;
const int8_t ROTARY_PRESS = 49;

const int8_t GND_PIN1 = 50;
const int8_t GND_PIN2 = 51;
const int8_t GND_PIN3 = 52;

const int8_t PIEZO_DATA_IN1 = A15;
const int8_t PIEZO_DATA_IN2 = A14;
const int8_t PIEZO_DATA_IN3 = A13;
const int8_t PIEZO_DATA_IN4 = A12;
const int8_t PIEZO_DATA_IN5 = A11;

const int8_t output_pins[] = {
  METRONOME,
  SCREEN_DATA0, SCREEN_DATA1, SCREEN_DATA2, SCREEN_DATA3,
  SCREEN_DATA4, SCREEN_DATA5, SCREEN_DATA6, SCREEN_DATA7, 
  SCREEN_EN, SCREEN_RW,SCREEN_RS,
  LED_DATA1, LED_DATA2, LED_DATA3, LED_DATA4, LED_DATA5, 
  PIEZO_C, PIEZO_B, PIEZO_A, 
  SLOW_SRCLK, SLOW_RCLK, SLOW_SRCLR, 
  FAST_SRCLK, FAST_RCLK, FAST_SRCLR, 
  GND_PIN1, GND_PIN2, GND_PIN3
};

const int8_t input_pins[] = {
  PIEZO_DATA_IN1, PIEZO_DATA_IN2, PIEZO_DATA_IN3, PIEZO_DATA_IN4, PIEZO_DATA_IN5};

// ==================== DATA ====================

// ===== DATA ===== Rotary Encoder ======
// adapted from http://bildr.org/2012/08/rotary-encoder-arduino/
volatile int lastEncoded = 0;
volatile long encoderValue = 0;

static long lastencoderValue = 0;
static int lastMSB = 0;
static int lastLSB = 0;

// ===== DATA ===== Piezo Sensors ======
//triggered values
volatile int trigger_value[5][8] = {{0}, {0}, {0}, {0}, {0}};
static int current_column = 0;

// ===== DATA ===== LCD Screen =====
LiquidCrystal lcd(SCREEN_RS, SCREEN_EN, SCREEN_DATA4, SCREEN_DATA5, SCREEN_DATA6, SCREEN_DATA7);

// ===== DATA ===== Bluetooth =====
volatile static byte incomingByte = 0;

// ===== DATA ===== MIDI =====
MIDIEvent MIDI_events[MAX_MIDI_EVENTS] = {0};
int MIDI_events_write_idx = 0;


// ===== DATA ===== DEBUG =====
#if DEBUG_MODE
static int count = 0;
#endif

// =============== Finite State Machine(FSM) ===============

// time read state: 
//  0 - not read/initial
//  1 - already read time
static uint8_t time_read_state = 0;

// metronome state: 0 - init, 1 -> 3 -  wait, 4 - fire
static uint8_t metronome_state = 0;
static bool metronome_enabled = 0;
static bool metronome_turn_off_flag = false;
static uint8_t metronome_volume = 50;
static double tempo_factor = 1.0;

// setting state
//  0 - volume
//  1 - tempo speed
static volatile uint8_t setting_state = 0;

// SYS state:
//  0 - initial state/normal
//  1 - loading state
//  2 - playback state
static volatile uint8_t SYS_state = 0;

// BT state
//  0 - wait for init, 
//  1 - wait for value, 
static int8_t BT_state = 0; 

// ================ HELPER FUNCTIONS ================ 
 
// MIDI note number to Music Note name
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

void piezo_interrupt_handler(){
  piezo_loop(input_pins);
}

void piezo_loop(const int8_t piezo_data_pins[]) {
  for(int i = 0;i< 8;i++){
    digitalWrite(PIEZO_C, (i >> 2) & 0x01);
    digitalWrite(PIEZO_B, (i >> 1) & 0x01);
    digitalWrite(PIEZO_A, i & 0x01);

    for(int j = 0;j<5;j++){
      trigger_value[j][i] = analogRead(piezo_data_pins[j]);
      if(trigger_value[j][i] > PIEZO_THRESHOLD) {
        trigger_value[j][i] = 0;

#if DEBUG_MODE
        Serial.print("knock detected: ");
        Serial.println(noteForMidiNumber((j*8+i+1) + 47));
#endif
      }
    }
  }
}

/*
 * =============== MAIN FUNCTION LOOP ==============
 */
static bool clear_bit_shifter = true;

void setup() {  
#if DEBUG_MODE
      Serial.begin(57600);
      Serial.println("Setup Arduino...");
#endif  
  int8_t num_outputs = sizeof(output_pins);
  int8_t num_inputs = sizeof(input_pins);
  // init output pins
#if DEBUG_MODE
  Serial.println();
  Serial.print("init output pins: ");
#endif

  for(int i = 0; i < num_outputs;i++){
    pinMode(output_pins[i], OUTPUT);
#if DEBUG_MODE
      Serial.print(" ");
      Serial.print(output_pins[i]);
#endif
  }
  // init input pins (as interrupts)
#if DEBUG_MODE
  Serial.println("");
  Serial.print("init input pins: ");
#endif
  for(int i = 0; i < num_inputs;i++){
    pinMode(input_pins[i], INPUT);
#if DEBUG_MODE
    Serial.print(" ");
    Serial.print(input_pins[i]);
#endif
    // PCintPort::attachPinChangeInterrupt(input_pins[i],piezo_interrupt_handler,RISING);
  }

  // set rotary encoder
  pinMode(ROTARY_A,INPUT);
  pinMode(ROTARY_B,INPUT);
  pinMode(ROTARY_PRESS,INPUT);
  digitalWrite(ROTARY_A,HIGH);
  digitalWrite(ROTARY_B,HIGH);
  digitalWrite(ROTARY_PRESS,HIGH);
  PCintPort::attachInterrupt(ROTARY_A, updateEncoder, CHANGE);
  PCintPort::attachInterrupt(ROTARY_B, updateEncoder, CHANGE);
  PCintPort::attachInterrupt(ROTARY_PRESS, updateRotarySettingState, CHANGE);
#if DEBUG_MODE
  Serial.println();
#endif
  BLEmini.begin(57600);

  // CLR bit shifter
  if (clear_bit_shifter) {
    digitalWrite(SLOW_SRCLR,LOW);
    digitalWrite(FAST_SRCLR,LOW);
    clear_bit_shifter = false;
  }

  // set fixed pins
  digitalWrite(SLOW_SRCLR,HIGH);
  digitalWrite(FAST_SRCLR,HIGH);
  digitalWrite(GND_PIN1,LOW);
  digitalWrite(GND_PIN2,LOW);
  digitalWrite(GND_PIN3,LOW);
  digitalWrite(SCREEN_RW,LOW);
  
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
// other - pause state
//  --- set CLK frequency here ---
static int slow_clk_freq = 8 * tempo_factor; // 16th note time = 60/120/4 = 0.125s ~ 8Hz
static int freq_metronome = slow_clk_freq/4;
static int delay_time_metronome = 1000/freq_metronome/2;
static int on_time_metronome = 20;

static uint16_t CLK_state = 0;
static int delay_time = 1000/slow_clk_freq/2/8;
static bool pause_clk_flag = false;
static char LED_data[5] = {0b00000000,0b00000000,0b00000000,0b00000000,0b00000000};
bool dim_light[5] = {false};
const int8_t LED_data_pin[5] = {LED_DATA1,LED_DATA2,LED_DATA3,LED_DATA4,LED_DATA5};

void CLK_GEN_helper() {
  // clock logic
  if (CLK_state > 16) return;
  if (CLK_state == 1){
    digitalWrite(SLOW_SRCLK, HIGH);
    digitalWrite(SLOW_RCLK, LOW);

    // metronome synced with slow clk
    metronome_state++;
    if(metronome_state == 4){
      if(metronome_enabled){
        analogWrite(METRONOME,metronome_volume);
        metronome_turn_off_flag = true;
      }
      previous_millis_metronome = millis();
    } else if(metronome_state == 5){
      metronome_state = 1;
    }
    
  } 
  if (CLK_state == 9){
    digitalWrite(SLOW_SRCLK, LOW);
    digitalWrite(SLOW_RCLK, HIGH);
  }
  if(CLK_state % 2 != 0){
    digitalWrite(FAST_SRCLK, HIGH);
    digitalWrite(FAST_RCLK, LOW);
      for(int i = 0; i < 5; i++){
        if((LED_data[i] >> (9-(17-CLK_state)/2)) & (0x1) == 1){
          dim_light[i] = true;
          digitalWrite(LED_data_pin[i],HIGH);
        }
      }
  } else {
    digitalWrite(FAST_SRCLK, LOW);
    digitalWrite(FAST_RCLK, HIGH); 
      for(int i = 0; i < 5; i++){
        if(dim_light[i]){
          dim_light[i] = false;
          digitalWrite(LED_data_pin[i],LOW);
        }
      } 
  }
  
  previous_millis_CLK = millis();
  CLK_state *= 100; // make the state 
}

// Asynchronous Clock Generator
// metronome is kept in sync with the clk
void CLK_GEN() {
  if(metronome_turn_off_flag){
    if(millis() - previous_millis_metronome > on_time_metronome){
      analogWrite(METRONOME,0);
      metronome_turn_off_flag = false;
    }
  }
  if (CLK_state == 0 && !pause_clk_flag) {
    CLK_state = 1;
  } else if (CLK_state > 16) {
    if(millis() - previous_millis_CLK >= delay_time){
      CLK_state = CLK_state/100 + 1;
      if(CLK_state == 17) CLK_state = 1;
    }
  } else {
    CLK_GEN_helper();
  }
}

void updateEncoder(){
  int MSB = digitalRead(ROTARY_A); //MSB = most significant bit
  int LSB = digitalRead(ROTARY_B); //LSB = least significant bit

  int encoded = (MSB << 1) |LSB; //converting the 2 pin value to single number
  int sum  = (lastEncoded << 2) | encoded; //adding it to the previous encoded value

  int prev_encoder_value = encoderValue;

  if(sum == 0b1101 || sum == 0b0100 || sum == 0b0010 || sum == 0b1011) encoderValue++;
  if(sum == 0b1110 || sum == 0b0111 || sum == 0b0001 || sum == 0b1000) encoderValue--;

  if(encoderValue - prev_encoder_value > 0){ // CW
    if(setting_state == 0){ // volume up
      if(metronome_volume + 25 <250){
        metronome_volume += 25;
      } else {
        metronome_volume = 250;
      }
    } else if (setting_state == 1){ // tempo speed up
      if(SYS_state != 1){
        if(tempo_factor + 0.1 < 2.0){
          tempo_factor += 0.1;
          slow_clk_freq = 8 * tempo_factor;
          freq_metronome = slow_clk_freq/4;
          delay_time_metronome = 1000/freq_metronome/2;
          delay_time = 1000/slow_clk_freq/2/8;
        }
      }
    }
  } else if (encoderValue - prev_encoder_value < 0){ // CCW
    if(setting_state == 0){ // volume down
      if(int(metronome_volume) - 25 > 0){
        metronome_volume -= 25;
      } else {
        metronome_volume = 250;
      }
    } else if (setting_state == 1){ // tempo speed down
      if(SYS_state != 1){
        if(tempo_factor - 0.1 > 0.3){
          tempo_factor -= 0.1;
          slow_clk_freq = 8 * tempo_factor;
          freq_metronome = slow_clk_freq/4;
          delay_time_metronome = 1000/freq_metronome/2;
          delay_time = 1000/slow_clk_freq/2/8;
        }
      }
    }
  }

  lastEncoded = encoded; //store this value for next time
}


void updateRotarySettingState(){
  int value_read = digitalRead(ROTARY_PRESS);
  if(!value_read){ //button is  pushed
    if(setting_state == 0){
      // Serial.print("Tempo Speed setting");
      setting_state = 1;
    } else if (setting_state == 1) { 
      // Serial.print("Metronome Volume setting");
      setting_state = 0;
    }
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





 /* ================ STRUCT DEFINITION ================ 
 * 
 */

enum MIDIEventType {
  MIDI_TIME_EVENT,
  MIDI_NOTE_ON_EVENT,
  MIDI_FUNC_CODE_EVENT,
  MIDI_NOTE_OFF_EVENT
};


uint8_t note_type(MIDIEvent e) {
  return (e & 0b11000000) >> 6;
}
uint8_t note_content(MIDIEvent e) {
  return e & 0x3F;
}


void play_next_MIDI_event() {
  if(MIDI_events[MIDI_events_write_idx] == END_OF_MIDI_STREAM) {
    SYS_state = 0;
    BLEmini.write(RESP_END_PLAYBACK);
    return;
  }

  // start reading time bytes
  if(time_read_state == 0){
    // when it reaches the end of the buffer
    
    // current pointer is time note, read both them
    if ( note_type(MIDI_events[MIDI_events_write_idx]) ==  MIDI_TIME_EVENT) {
      
      uint16_t p1 = note_content(MIDI_events[MIDI_events_write_idx]);
      uint16_t p2 = note_content(MIDI_events[MIDI_events_write_idx+1]);
      curEventInterval_MIDI = ((p1 << 6) | p2)/tempo_factor;
#if DEBUG_MODE
//      Serial.print(curEventInterval_MIDI);
//      Serial.print(" ");
#endif
      time_read_state = 1;
      // skip the second time byte
      MIDI_events_write_idx += 2;
    }
  } else if (time_read_state == 1 && (millis() - previous_millis_MIDI) >= curEventInterval_MIDI) {  // when time is already read, read notes on/off info
    previous_millis_MIDI = millis();
    // when not finishing read the notes
    while(time_read_state == 1) {
#if DEBUG_MODE
//      Serial.print(note_content(MIDI_events[MIDI_events_write_idx]),DEC);
//      Serial.print(" ");
#endif
      if (note_type(MIDI_events[MIDI_events_write_idx]) == MIDI_NOTE_ON_EVENT) { // on
        turn_on_note_num(note_content(MIDI_events[MIDI_events_write_idx]));
      } else if (note_type(MIDI_events[MIDI_events_write_idx]) == MIDI_NOTE_OFF_EVENT) { // off
        turn_off_note_num(note_content(MIDI_events[MIDI_events_write_idx]));
      }
  
      // move to the next 
      MIDI_events_write_idx += 1;
      if(note_type(MIDI_events[MIDI_events_write_idx]) == MIDI_TIME_EVENT){
        time_read_state = 0;
#if DEBUG_MODE
//         Serial.println(" ");
#endif
      } 
      // when run into the end of file
      if(note_content(MIDI_events[MIDI_events_write_idx]) == 0 || MIDI_events[MIDI_events_write_idx] == END_OF_MIDI_STREAM) {
        time_read_state = 0;
        SYS_state = 0;
        BLEmini.write(RESP_END_PLAYBACK);
        return;
      }
    }

#if DEBUG_MODE
    // display keys
    for(int i = 0;i<5;i++){
      print_char(LED_data[i]);
    }
    Serial.println("");
#endif
  }

  
}

// n starts from 1 to 36
void turn_on_note_num(char n) {
  if(n == 0) {
    return;
  }
  char idx = (n-1)/8;
  LED_data[idx] = LED_data[idx] | (1 << (8-(n%8)));

}
void turn_off_note_num(char n) {
  if(n == 0) {
    return;
  }
  char idx = (n-1)/8;
  LED_data[idx] = LED_data[idx] & (~(1 << (8-(n%8))));
}

void print_char(char n) {
  for(int i = 0; i < 8; i++){
    Serial.print((n >> (7-i)) & 0x1);
  }
}

// Bluetooth Message Handler
void bt_msg_handler() {
  switch (incomingByte) {
    // Start Loading MIDI Data
    case FUNC_START_LOADING:
      if(SYS_state == 0){
        BLEmini.write(RESP_START_CONNECTION);
        SYS_state = 1;
#if DEBUG_MODE
        Serial.println("FUNC_START_LOADING");
        Serial.println(count);
#endif
      }
      break;

    // Stop Loading MIDI Data
    case FUNC_STOP_LOADING:
      if(SYS_state == 1){
        BLEmini.write(RESP_END_CONNECTION);
        SYS_state = 0;

        // add a eof at the end of the file
        MIDI_events[MIDI_events_write_idx++] = END_OF_MIDI_STREAM;
#if DEBUG_MODE
        Serial.println("FUNC_STOP_LOADING");
        Serial.println(count);
        count = 0;
#endif
        MIDI_events_write_idx = 0;
      }
      break;

    // Head Byte of large byte package
    case FUNC_START_OF_DATA_TRANSMISSION:
      BT_state = 1;
      break;
    // Tail Byte of larget byte package
    case FUNC_END_OF_DATA_TRANSMISSION:
      BT_state = 0;
      BLEmini.write(RESP_ACKNOWLEDGE);
#if DEBUG_MODE
      if (SYS_state == 1)
      {
        count++;
      }
      
#endif
      break;

    // Start Playing Back
    case FUNC_START_PLAYBACK:
      if(SYS_state == 0){
        pause_clk_flag = false;
        SYS_state = 2;
//        MIDI_events_write_idx = 0;
        BLEmini.write(RESP_START_PLAYBACK);
#if DEBUG_MODE
        Serial.println("FUNC_START_PLAYBACK");
#endif
      }
      break;

    // Pause Playing Back
    case FUNC_PAUSE_PLAYBACK:
      if(SYS_state == 2){
        pause_clk_flag = true;
        SYS_state = 0;
        BLEmini.write(RESP_END_PLAYBACK);
#if DEBUG_MODE
        Serial.println("FUNC_END_PLAYBACK");
#endif
      }
      break;

    // Toggle Metronome Beats
    case FUNC_TOGGLE_METRONOME:
      if(SYS_state == 2){
        if(metronome_enabled){
          metronome_enabled = false;
        }else{
          metronome_enabled = true;
        }
        BLEmini.write(RESP_TOGGLE_METRONOME);
#if DEBUG_MODE
        Serial.println("RESP_TOGGLE_METRONOME");
#endif
      }

    // Metronome Volume UP
    case FUNC_METRONOME_VOL_UP:
      if(int(metronome_volume) + 20 > 250){
        metronome_volume = 250;
      } else {
        metronome_volume += 20;
      }
      BLEmini.write(RESP_ACKNOWLEDGE);
#if DEBUG_MODE
      Serial.println("FUNC_METRONOME_VOL_UP");
#endif
      break;

    // Metronome Volume Down
    case FUNC_METRONOME_VOL_DOWN:
      if(int(metronome_volume) - 20 < 0){
        metronome_volume = 0;
      } else {
        metronome_volume -= 20;
      }
      BLEmini.write(RESP_ACKNOWLEDGE);
#if DEBUG_MODE
      Serial.println("FUNC_METRONOME_VOL_DOWN");
#endif
      break;
    case FUNC_TEMP_ADJUST_UP:
      if(SYS_state != 1){
        if(tempo_factor + 0.1 < 2.0){
          tempo_factor += 0.1;
          slow_clk_freq = 8 * tempo_factor;
          freq_metronome = slow_clk_freq/4;
          delay_time_metronome = 1000/freq_metronome/2;
          delay_time = 1000/slow_clk_freq/2/8;
        }
#if DEBUG_MODE
        Serial.println("FUNC_TEMP_ADJUST_UP");
#endif
      }
      
      BLEmini.write(RESP_ACKNOWLEDGE);
      break;
    case FUNC_TEMP_ADJUST_DOWN:
      if(SYS_state != 1){
        if(tempo_factor - 0.1 > 0.3){
          tempo_factor -= 0.1;
          slow_clk_freq = 8 * tempo_factor;
          freq_metronome = slow_clk_freq/4;
          delay_time_metronome = 1000/freq_metronome/2;
          delay_time = 1000/slow_clk_freq/2/8;
        }
#if DEBUG_MODE
        Serial.println("FUNC_TEMP_ADJUST_DOWN");
#endif
      }
      
      BLEmini.write(RESP_ACKNOWLEDGE);
      break;
    default:  // General Data Bytes
      // if the message's header is either note on or note off or time
      if ((incomingByte >> 6) == 0b01 || (incomingByte >> 6) == 0b11 || (incomingByte >> 6) == 0b00)
      {
        if(BT_state == 1) { // when transmiting data
          uint8_t msg_type = ((incomingByte >> 6)&0x3);
          uint8_t msg_note = (incomingByte & 0x3f);
          if(msg_type != 0b10) {
            if(MIDI_events_write_idx < MAX_MIDI_EVENTS -1){
              MIDI_events[MIDI_events_write_idx++] = incomingByte;  
            }
          }
        }
      }
      
    break;
  }
}


void loop() {
  // when first run the loop, beep 3 times to indicate it's successfully initialized
  if(!ran_once_flag) {
    ran_once_flag = true;
    for (int i = 0; i < 3; i++)
    {
      analogWrite(METRONOME, metronome_volume);
      delay(30);
      analogWrite(METRONOME, 0);
      delay(300);
    }
  }

  // when Bluetooth Data comes in
  if(BLEmini.available() > 0) {
    incomingByte = BLEmini.read();
    bt_msg_handler();
  }

  // SYS_state state-specific cases
  switch (SYS_state) {
    case 0: // normal/initial state

      break;
    case 1:  // music loading state

      break;
    case 2: // Playing Back state 
      if(!pause_clk_flag){
        CLK_GEN();
      }
      play_next_MIDI_event();
//      piezo_loop(input_pins);
      break;
    default:
      break;
  }  
}
