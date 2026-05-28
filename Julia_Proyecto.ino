#include <WiFi.h>
#include <WebServer.h>
#include <DHT.h>
#include <Wire.h>
#include <Adafruit_BMP280.h>

const char* ssid = "MOCOCITOS_mundial";
const char* password = "1234567890";

WebServer server(80);

#define DHTPIN 4
#define DHTTYPE DHT22

#define LDR_PIN 27
#define RAIN_PIN 35

DHT dht(DHTPIN, DHTTYPE);
Adafruit_BMP280 bmp;

float temperatura;
float humedad;
float presion;

int luz;
int lluvia;

unsigned long ultimoTiempo = 0;

// =====================================================
// PAGINA HTML
// =====================================================

String paginaHTML() {

  String html = "<!DOCTYPE html>";

  html += "<html>";
  html += "<head>";

  html += "<meta charset='UTF-8'>";
  html += "<meta http-equiv='refresh' content='2'>";

  html += "<title>Prediccion de Clima y Lluvia</title>";

  html += "<style>";

  html += "body{";
  html += "font-family:Arial;";
  html += "background:#0f172a;";
  html += "color:white;";
  html += "text-align:center;";
  html += "padding:20px;";
  html += "}";

  html += "h1{";
  html += "color:#38bdf8;";
  html += "font-size:40px;";
  html += "}";

  html += ".card{";
  html += "background:#1e293b;";
  html += "padding:20px;";
  html += "margin:20px auto;";
  html += "border-radius:15px;";
  html += "width:300px;";
  html += "box-shadow:0px 0px 15px rgba(0,0,0,0.5);";
  html += "}";

  html += ".valor{";
  html += "font-size:30px;";
  html += "color:#22c55e;";
  html += "}";

  html += ".equipo{";
  html += "margin-top:40px;";
  html += "font-size:20px;";
  html += "color:#cbd5e1;";
  html += "}";

  html += "</style>";

  html += "</head>";

  html += "<body>";

  html += "<h1>Prediccion de Clima y Lluvia</h1>";

  // ================= TEMPERATURA =================

  html += "<div class='card'>";
  html += "<h2>Temperatura</h2>";
  html += "<p class='valor'>";
  html += String(temperatura);
  html += " °C</p>";
  html += "</div>";

  // ================= HUMEDAD =================

  html += "<div class='card'>";
  html += "<h2>Humedad</h2>";
  html += "<p class='valor'>";
  html += String(humedad);
  html += " %</p>";
  html += "</div>";

  // ================= PRESION =================

  html += "<div class='card'>";
  html += "<h2>Presion Atmosferica</h2>";
  html += "<p class='valor'>";
  html += String(presion);
  html += " hPa</p>";
  html += "</div>";

  // ================= LUZ =================

  html += "<div class='card'>";
  html += "<h2>Estado de Luz</h2>";

  if (luz == 1) {
    html += "<p class='valor'>Oscuro</p>";
  } else {
    html += "<p class='valor'>Con Luz</p>";
  }

  html += "</div>";

  // ================= LLUVIA =================

  html += "<div class='card'>";
  html += "<h2>Sensor de Lluvia</h2>";
  html += "<p class='valor'>";
  html += String(lluvia);
  html += "</p>";
  html += "</div>";

  // ================= EQUIPO =================

  html += "<div class='equipo'>";

  html += "<h2>Equipo</h2>";

  html += "<p>Daniel Ruiz Trejo</p>";
  html += "<p>Victor Alexis Diaz Morales</p>";
  html += "<p>David Israel Guerrero Estrada</p>";

  html += "</div>";

  html += "</body>";
  html += "</html>";

  return html;
}

// =====================================================
// JSON PARA JULIA
// =====================================================

void enviarDatosJSON() {

  String json = "{";

  json += "\"temperatura\":";
  json += String(temperatura);
  json += ",";

  json += "\"humedad\":";
  json += String(humedad);
  json += ",";

  json += "\"presion\":";
  json += String(presion);
  json += ",";

  json += "\"luz\":";
  json += String(luz);
  json += ",";

  json += "\"lluvia\":";
  json += String(lluvia);

  json += "}";

  server.send(200, "application/json", json);
}

// =====================================================
// SETUP
// =====================================================

void setup() {

  Serial.begin(115200);

  dht.begin();

  if (!bmp.begin(0x76)) {

    Serial.println("ERROR_BMP280");

    while (1);

  }

  pinMode(LDR_PIN, INPUT);

  analogReadResolution(12);

  WiFi.begin(ssid, password);

  Serial.print("Conectando WiFi");

  while (WiFi.status() != WL_CONNECTED) {

    delay(500);
    Serial.print(".");

  }

  Serial.println();
  Serial.println("WiFi conectado");

  Serial.print("IP del ESP32: ");
  Serial.println(WiFi.localIP());

  // PAGINA WEB
  server.on("/", []() {

    server.send(200, "text/html", paginaHTML());

  });

  // JSON
  server.on("/datos", enviarDatosJSON);

  server.begin();

  Serial.println("Servidor iniciado");
}

// =====================================================
// LOOP
// =====================================================

void loop() {

  server.handleClient();

  if (millis() - ultimoTiempo >= 1500) {

    ultimoTiempo = millis();

    temperatura = dht.readTemperature();
    humedad = dht.readHumidity();

    presion = bmp.readPressure() / 100.0F;

    // SENSOR LDR
    luz = digitalRead(LDR_PIN);

    // SENSOR LLUVIA
    lluvia = analogRead(RAIN_PIN);

    // VALIDACION
    if (isnan(temperatura) || isnan(humedad)) {

      Serial.println("ERROR_DHT");
      return;

    }

    // SERIAL CSV
    Serial.print(temperatura);
    Serial.print(",");

    Serial.print(humedad);
    Serial.print(",");

    Serial.print(presion);
    Serial.print(",");

    Serial.print(luz);
    Serial.print(",");

    Serial.println(lluvia);
  }
}