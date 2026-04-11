
from pymobiledevice3.services.diagnostics import DiagnosticsService
from pymobiledevice3 import usbmux
from pymobiledevice3.lockdown import create_using_usbmux
import sys

for device in usbmux.list_devices():
    if device.is_usb:
        lockdown = create_using_usbmux(serial=device.serial)
    
lockdown = None
for device in usbmux.list_devices():
    if device.is_usb:
        lockdown = create_using_usbmux(serial=device.serial)
        with DiagnosticsService(lockdown) as mb:
            mb.restart()

if lockdown is None:
    print("Error: No connected device found.")
    sys.exit(1)

print("Rebooting Device...")