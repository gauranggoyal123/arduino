/*
 * Copyright (C) 2006-2008 Free Software Foundation.  All rights reserved.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * See file LICENSE.txt for further informations on licensing terms.
 */

/* 
 * TODO: generalized SysEx support
 * TODO: Bjoen Servo support
 * TODO: Firmata.read() callback registry
 * TODO: pulseOut functionality for servos
 * TODO: software PWM for servos, etc (servo.h or pulse.h)
 * TODO: device type reporting (i.e. some firmwares will use the Firmata
 *       protocol, but will only support specific devices, like ultrasound 
 *       rangefinders or servos)
 * TODO: use Program Control to load stored profiles from EEPROM
 */

#include <EEPROM.h>
#include <Firmata.h>

/*==============================================================================
 * GLOBAL VARIABLES
 *============================================================================*/

/* analog inputs */
int analogInputsToReport = 0xffff; // bitwise array to store pin reporting
int analogPin = 0; // counter for reading analog pins
/* digital pins */
int digitalInputs;
int previousDigitalInputs; // previous output to test for change
/* timer variables */
extern volatile unsigned long timer0_overflow_count; // timer0 from wiring.c
unsigned long nextExecuteTime; // for comparison with timer0_overflow_count

/*==============================================================================
 * FUNCTIONS                                                                
 *============================================================================*/

/* -----------------------------------------------------------------------------
 * check all the active digital inputs for change of state, then add any events
 * to the Serial output queue using Serial.print() */
void checkDigitalInputs(void) 
{
    previousDigitalInputs = digitalInputs;
    digitalInputs = PINB << 8;  // get pins 8-13
    digitalInputs += PIND;      // get pins 0-7
    if(digitalInputs != previousDigitalInputs) {
		// TODO: implement more ports as channels for more than 16 digital pins
		Firmata.sendDigitalPortPair(0, digitalInputs); // port 0 till more are implemented
    }
}

/*==============================================================================
 * SETUP()
 *============================================================================*/
void setup() 
{
    Firmata.begin();

    // TODO: load state from EEPROM here

    /* TODO: send digital inputs here, if enabled, to set the initial state on the
     * host computer, since once in the loop(), the Arduino will only send data on
     * change. */
}

/*==============================================================================
 * LOOP()
 *============================================================================*/
void loop() 
{
/* DIGITALREAD - as fast as possible, check for changes and output them to the
 * FTDI buffer using Serial.print()  */
    checkDigitalInputs();  
    if(timer0_overflow_count > nextExecuteTime) {  
        nextExecuteTime = timer0_overflow_count + 19; // run this every 20ms
        /* SERIALREAD - Serial.read() uses a 128 byte circular buffer, so handle
         * all serialReads at once, i.e. empty the buffer */
        while(Firmata.available())
            Firmata.processInput();
        /* SEND FTDI WRITE BUFFER - make sure that the FTDI buffer doesn't go over
         * 60 bytes. use a timer to sending an event character every 4 ms to
         * trigger the buffer to dump. */
	
        /* ANALOGREAD - right after the event character, do all of the
         * analogReads().  These only need to be done every 4ms. */
        for(analogPin=0;analogPin<TOTAL_ANALOG_PINS;analogPin++) {
            if( analogInputsToReport & (1 << analogPin) ) 
                Firmata.sendAnalog(analogPin, analogRead(analogPin));
        }
    }
}