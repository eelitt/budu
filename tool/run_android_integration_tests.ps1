param(
  [string]$DeviceId
)

$devices = @(flutter devices --machine | ConvertFrom-Json)
$androidDevices = @($devices | Where-Object { $_.targetPlatform -like 'android*' })

if ($androidDevices.Count -eq 0) {
  throw 'No Android device is connected. Connect an Android device and try again.'
}

$device = if ($DeviceId) {
  $androidDevices | Where-Object { $_.id -eq $DeviceId } | Select-Object -First 1
} else {
  $androidDevices | Select-Object -First 1
}

if ($null -eq $device) {
  throw "Android device '$DeviceId' was not found."
}

flutter drive --driver=test_driver/integration_test.dart --target=integration_test/updater_android_test.dart -d $device.id
exit $LASTEXITCODE
