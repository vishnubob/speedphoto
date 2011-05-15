#include <util/delay.h>

#define CAMERA_PIN          10
#define LASER_PIN           11
#define LASER_SENSOR_PIN    0

unsigned char camera_armed = 0;
unsigned int laser_sensor_value;
unsigned int laser_threshold;
unsigned int exposure_delay;
int drip_step_value = -20;

// Helper macros for frobbing bits
#define bitset(var,bitno) ((var) |= (1 << (bitno)))
#define bitclr(var,bitno) ((var) &= ~(1 << (bitno)))
#define bittst(var,bitno) (var& (1 << (bitno)))

/******************************************************************************
 ** Stepper motor
 ******************************************************************************/

typedef struct BipolarStepper
{
    unsigned char   CoilA_PosA_pin;
    unsigned char   CoilA_NegA_pin;
    unsigned char   CoilA_PosB_pin;
    unsigned char   CoilA_NegB_pin;
    unsigned char   CoilB_PosA_pin;
    unsigned char   CoilB_NegA_pin;
    unsigned char   CoilB_PosB_pin;
    unsigned char   CoilB_NegB_pin;
    char            step_state;
    long            current_step;
};

BipolarStepper StepperMotors[1];
BipolarStepper *stepper;

void coast(BipolarStepper *s)
{
    digitalWrite(s->CoilA_PosA_pin, LOW);
    digitalWrite(s->CoilA_NegA_pin, HIGH);
    digitalWrite(s->CoilA_PosB_pin, LOW);
    digitalWrite(s->CoilA_NegB_pin, HIGH);
    digitalWrite(s->CoilB_PosA_pin, LOW);
    digitalWrite(s->CoilB_NegA_pin, HIGH);
    digitalWrite(s->CoilB_PosB_pin, LOW);
    digitalWrite(s->CoilB_NegB_pin, HIGH);
}

void home(BipolarStepper *s)
{
    s->current_step = 0;
}

BipolarStepper *attach_stepper(
    unsigned char CoilA_PosA_pin, unsigned char CoilA_NegA_pin, 
    unsigned char CoilA_PosB_pin, unsigned char CoilA_NegB_pin, 
    unsigned char CoilB_PosA_pin, unsigned char CoilB_NegA_pin, 
    unsigned char CoilB_PosB_pin, unsigned char CoilB_NegB_pin)
{
    pinMode(CoilA_PosA_pin, OUTPUT);
    pinMode(CoilA_NegA_pin, OUTPUT);
    pinMode(CoilA_PosB_pin, OUTPUT);
    pinMode(CoilA_NegB_pin, OUTPUT);
    pinMode(CoilB_PosA_pin, OUTPUT);
    pinMode(CoilB_NegA_pin, OUTPUT);
    pinMode(CoilB_PosB_pin, OUTPUT);
    pinMode(CoilB_NegB_pin, OUTPUT);
    StepperMotors[0].CoilA_PosA_pin = CoilA_PosA_pin;
    StepperMotors[0].CoilA_NegA_pin = CoilA_NegA_pin;
    StepperMotors[0].CoilA_PosB_pin = CoilA_PosB_pin;
    StepperMotors[0].CoilA_NegB_pin = CoilA_NegB_pin;
    StepperMotors[0].CoilB_PosA_pin = CoilB_PosA_pin;
    StepperMotors[0].CoilB_NegA_pin = CoilB_NegA_pin;
    StepperMotors[0].CoilB_PosB_pin = CoilB_PosB_pin;
    StepperMotors[0].CoilB_NegB_pin = CoilB_NegB_pin;
    coast(&(StepperMotors[0]));
    return &(StepperMotors[0]);
}

    
void _step(BipolarStepper *s, char direction)
{
    switch(s->step_state)
    {
        // R1 = PosA
        // R2 = NegA
        // R3 = PosB
        // R4 = NegB
        case 0:
            digitalWrite(s->CoilA_PosA_pin, LOW);
            digitalWrite(s->CoilA_PosB_pin, LOW);
            digitalWrite(s->CoilA_NegB_pin, HIGH);
            digitalWrite(s->CoilB_PosA_pin, LOW);
            digitalWrite(s->CoilB_NegA_pin, HIGH);
            digitalWrite(s->CoilB_NegB_pin, HIGH);
            /* A = POS; B = OFF */
            digitalWrite(s->CoilA_NegA_pin, LOW);
            digitalWrite(s->CoilA_PosB_pin, HIGH);
            s->step_state = direction ? 1 : 3;
            break;
        case 1:
            digitalWrite(s->CoilA_PosA_pin, LOW);
            digitalWrite(s->CoilA_NegA_pin, HIGH);
            digitalWrite(s->CoilA_PosB_pin, LOW);
            digitalWrite(s->CoilA_NegB_pin, HIGH);
            digitalWrite(s->CoilB_PosA_pin, LOW);
            digitalWrite(s->CoilB_NegB_pin, HIGH);
            /* A = OFF; B = POS */
            digitalWrite(s->CoilB_NegA_pin, LOW);
            digitalWrite(s->CoilB_PosB_pin, HIGH);
            s->step_state = direction ? 2 : 0;
            break;
        case 2:
            digitalWrite(s->CoilA_NegA_pin, HIGH);
            digitalWrite(s->CoilA_PosB_pin, LOW);
            digitalWrite(s->CoilB_PosA_pin, LOW);
            digitalWrite(s->CoilB_NegA_pin, HIGH);
            digitalWrite(s->CoilB_PosB_pin, LOW);
            digitalWrite(s->CoilB_NegB_pin, HIGH);
            /* A = NEG; B = OFF */
            digitalWrite(s->CoilA_PosA_pin, HIGH);
            digitalWrite(s->CoilA_NegB_pin, LOW);
            _delay_us(1000);
            s->step_state = direction ? 3 : 1;
            break;
        case 3:
            digitalWrite(s->CoilA_PosA_pin, LOW);
            digitalWrite(s->CoilA_NegA_pin, HIGH);
            digitalWrite(s->CoilA_PosB_pin, LOW);
            digitalWrite(s->CoilA_NegB_pin, HIGH);
            digitalWrite(s->CoilB_NegA_pin, HIGH);
            digitalWrite(s->CoilB_PosB_pin, LOW);
            /* A = OFF; B = NEG */
            digitalWrite(s->CoilB_PosA_pin, HIGH);
            digitalWrite(s->CoilB_NegB_pin, LOW);
            s->step_state = direction ? 0 : 2;
            break;
    }
    s->current_step += (direction ? 1 : -1);
    _delay_us(3500);
}

void step(BipolarStepper *s, char direction)
{
    _step(s, direction);
    coast(s);
}

void goto_step(BipolarStepper *s, long val)
{
    char direction;
    direction = ((val - s->current_step) >= 0) ? 1 : 0;
    while(val != s->current_step)
    {
        _step(s, direction);
    }
    coast(s);
}

/******************************************************************************
 ** Laser
 ******************************************************************************/

void LaserOff (void)
{
    digitalWrite(LASER_PIN, LOW);
}

void LaserOn (void)
{
    digitalWrite(LASER_PIN, HIGH);
}

void LaserToggle (void)
{
    if(digitalRead(LASER_PIN))
    {
        LaserOff();
    } else
    {
        LaserOn();
    }
}

/******************************************************************************
 ** Camera
 ******************************************************************************/

void ArmCamera (void)
{
    LaserOn();
    _delay_us(10000);
    camera_armed = 1;
}

void DisarmCamera (void)
{
    LaserOff();
    camera_armed = 0;
}

void __inline__ TriggerCamera (void)
{
    digitalWrite(CAMERA_PIN, LOW);
    _delay_us(1000);
    digitalWrite(CAMERA_PIN, HIGH);
}

/******************************************************************************
 ** Serial
 ******************************************************************************/

void ReportStatus(void)
{
    Serial.println("");
    Serial.println("Stepper:");
    Serial.print("  step: ");
    Serial.println(stepper->current_step, DEC);
    Serial.print("  state: ");
    Serial.println(stepper->step_state, DEC);
    Serial.print("  drip step value: ");
    Serial.println(drip_step_value, DEC);
    Serial.println("Laser:");
    Serial.print("  sensor: ");
    Serial.println(laser_sensor_value, DEC);
    Serial.print("  threshold: ");
    Serial.println(laser_threshold, DEC);
    Serial.print("  delay: ");
    Serial.println(exposure_delay, DEC);
    Serial.println(OCR1A, DEC);
}

void Prompt(void)
{
  static long v = 0;

  if (Serial.available()) {
    char ch = Serial.read();

    switch(ch) {
      case '0'...'9':
        v = v * 10 + ch - '0';
        break;
      case '-':
        v *= -1;
        break;
      case 'z':
        v = 0;
        break;
      case 'r':
        goto_step(stepper, stepper->current_step + v);
        v = 0;
        break;
      case 's':
        goto_step(stepper, v);
        v = 0;
        break;
      case 'q':
        /* drip */
        goto_step(stepper, stepper->current_step + drip_step_value);
        break;
      case 'h':
        home(stepper);
        break;
      case 'x':
        TriggerCamera();
        break;
      case 'a':
        /* arm camera */
        ArmCamera();
        break;
      case 'f':
        /* arm camera */
        DisarmCamera();
        break;
      case 'l':
        /* toggle laser off/on */
        LaserToggle();
        break;
      case 't':
        /* laser threshold */
        laser_threshold = v;
        v = 0;
        break;
      case 'd':
        /* delay in ticks */
        exposure_delay = v;
        v = 0;
        break;
      case 'w':
        /* drip step constant */
        drip_step_value = v;
        v = 0;
        break;
      case 'p':
        /* Report on status of system */
        ReportStatus();
        break;
    }
    Serial.println("");
    Serial.print("Value:");
    Serial.println(v);
    Serial.print("> ");
  }
}

/******************************************************************************
 ** Main loop
 ******************************************************************************/

void loop()
{
    Prompt();
    //Serial.println(TCNT1, DEC);
}

/******************************************************************************
 ** Setup
 ******************************************************************************/

void setup()
{
  // disable global interrupts
  cli();

  // variables
  laser_threshold = 100;

  Serial.begin(9600);
  Serial.print("[");
  // setup output
  pinMode(CAMERA_PIN, OUTPUT);
  digitalWrite(CAMERA_PIN, HIGH);
  pinMode(LASER_PIN, OUTPUT);
  Serial.print("pins-");
  // Stepper motor
  stepper = attach_stepper(2,3,4,5,6,7,8,9);
  Serial.print("stepper-");

  // setup timer1 - 16
  // resonsible for timing the camera after an event
  TCCR1A = 0;
  TCCR1B = 0;
  // 1:256
  bitset(TCCR1B, CS12);
  // select CTC mode
  bitset(TCCR1A, WGM12);
  // enable compare interrupt
  Serial.print("timer-");

  // Configure the ADC
  ADMUX = (1 << 6) | (LASER_SENSOR_PIN & 0x0f);
  // start a converson
  bitset(ADCSRA, ADSC);
  // enable the interrupt to store the conversion result
  bitset(ADCSRA, ADIE);
  Serial.print("ADC");
  
  // enable global interrupts
  sei();

  Serial.println("]");
  Serial.flush();
}


/******************************************************************************
 ** Camera
 ******************************************************************************/

ISR(ADC_vect) 
{
    unsigned char low, high;

	low = ADCL;
	high = ADCH;
	laser_sensor_value =  (high << 8) | low;
    if ((camera_armed) && (laser_sensor_value > laser_threshold))
    {
        DisarmCamera();
        if(exposure_delay)
        {
            OCR1A = exposure_delay;
            TCNT1 = 0;
            /* clear any previous interrupt */
            bitset(TIFR1, OCF1A);
            /* configure the interrupt */
            bitset(TIMSK1, OCIE1A);
        } else
        {
            TriggerCamera();
        }
    }
    /* start the next conversion */
	bitset(ADCSRA, ADSC);
}

ISR(TIMER1_COMPA_vect) 
{
    TriggerCamera();
    /* disable this interrupt */
    bitclr(TIMSK1, OCIE1A);
}
