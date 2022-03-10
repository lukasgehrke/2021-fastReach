

int relay_pin = 7;
boolean EMS_STATE = false;
String received;

void setup() {
  Serial.begin(9600);
  Serial.setTimeout(1);
  pinMode(relay_pin, OUTPUT);
}

void loop() {
  if (Serial.available() > 0) {

    received = Serial.readString();
    Serial.println(received);
    Serial.println(EMS_STATE);

    if (received == "p" and EMS_STATE == true) {
      digitalWrite(relay_pin, LOW);
      EMS_STATE = false;
      Serial.println("turned off");
    }
    else if (received == "p" and EMS_STATE == false) {
      digitalWrite(relay_pin, HIGH);
      EMS_STATE = true;
      Serial.println("turned on");
    }
  }
}
