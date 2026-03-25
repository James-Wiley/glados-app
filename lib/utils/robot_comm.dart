// Utility function to send a single servo value to the robot

Future<void> sendServoValue(int servoIndex, double value) async {
  // TODO: Implement Bluetooth write logic
  // Expected behavior:
  // 1. Format message (e.g., "index,value" or JSON)
  // 2. Send via BLE characteristic write
  // 3. Handle connection errors / retries

  // Example format (string):
  // "0,90" -> servo 0 to 90 degrees

  print('TODO sendServoValue: servo=$servoIndex value=$value');
}
