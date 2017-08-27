
void otaSetup() {
  String ssid = WIFI_AP_PREFIX;
  ssid += chipId;
  ArduinoOTA.setHostname(ssid.c_str());

  ArduinoOTA.setPassword(logicConfig.adminPass.c_str());

  ArduinoOTA.onStart([]() {
    pixelsSet(0, 0, 0);
  });
  //  ArduinoOTA.onError([](ota_error_t error) {
  //    DBGPV("OTA update error: ", error);
  //  });
  ArduinoOTA.begin();
}
