param(
  [string]$DeviceId,
  [ValidateSet('all', 'updater', 'login')]
  [string]$Target = 'all'
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

$targets = switch ($Target) {
  'updater' { @('integration_test/updater_android_test.dart') }
  'login' { @('integration_test/login_android_test.dart') }
  default {
    @(
      'integration_test/updater_android_test.dart',
      'integration_test/login_android_test.dart'
    )
  }
}

foreach ($testTarget in $targets) {
  Write-Host "Running $testTarget on $($device.id)"
  flutter drive `
    --driver=test_driver/integration_test.dart `
    --target=$testTarget `
    -d $device.id
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

exit 0
