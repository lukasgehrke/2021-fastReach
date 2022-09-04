

int ems_relay_pin = 7;
boolean EMS_STATE = false;

int resist_relay_pin = 6;
boolean RES_STATE = false;

String received;

void setup() {
  Serial.begin(9600);
  Serial.setTimeout(1);
  pinMode(ems_relay_pin, OUTPUT);
  pinMode(resist_relay_pin, OUTPUT);
}

void loop() {
  if (Serial.available() > 0) {

    received = Serial.readString();
    Serial.println(received);
    Serial.println(EMS_STATE);

    if (received == "e" and EMS_STATE == true) {
      digitalWrite(ems_relay_pin, LOW);
      EMS_STATE = false;
      Serial.println("turned off");
    }
    else if (received == "e" and EMS_STATE == false) {
      digitalWrite(ems_relay_pin, HIGH);
      EMS_STATE = true;
      Serial.println("turned on");
    }

    if (received == "r" and RES_STATE == true) {
      digitalWrite(resist_relay_pin , LOW);
      RES_STATE = false;
      Serial.println("turned off");
    }
    else if (received == "r" and RES_STATE == false) {
      digitalWrite(resist_relay_pin , HIGH);
      RES_STATE = true;
      Serial.println("turned on");
    }

    
  }
}
