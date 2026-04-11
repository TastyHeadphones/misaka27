from pymobiledevice3.services.installation_proxy import InstallationProxyService
from pymobiledevice3 import usbmux
from pymobiledevice3.lockdown import create_using_usbmux
import json
from datetime import datetime

tips = ""

count = 0
for device in usbmux.list_devices():
    if device.is_usb:
        count += 1
        lockdown = create_using_usbmux(serial=device.serial)
        apps_json = InstallationProxyService(lockdown).get_apps(calculate_sizes=False)

        def decode_bytes(obj):
            if isinstance(obj, bytes):
                return obj.decode('utf-8') 
            elif isinstance(obj, dict):
                return {k: decode_bytes(v) for k, v in obj.items()}
            elif isinstance(obj, list):
                return [decode_bytes(i) for i in obj]
            elif isinstance(obj, datetime):
                return obj.isoformat()  # Convert datetime to string
            return obj
        
        apps_json_decoded = decode_bytes(apps_json)
        print(json.dumps(apps_json_decoded, indent=4))
        
if count == 0:
    print("NoDeviceConnectedError")
