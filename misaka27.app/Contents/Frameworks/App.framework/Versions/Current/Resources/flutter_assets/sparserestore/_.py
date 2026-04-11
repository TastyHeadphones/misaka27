from exploit.restore import restore_file
from pymobiledevice3.exceptions import PyMobileDevice3Exception
from pymobiledevice3.services.diagnostics import DiagnosticsService
from pymobiledevice3 import usbmux
from pymobiledevice3.lockdown import create_using_usbmux
import sys
import os
import traceback
import plistlib

def main():
    if len(sys.argv) != 3:
        print("Usage: restore.py <from_path> <to_path>")
        sys.exit(1)

    from_path = sys.argv[1]
    to_path = sys.argv[2]
    backup_path = os.path.dirname(to_path) + "/"

    print(f"[Restore] {from_path} -> {to_path}")

    e_contents = b"0x00"
    if from_path != "Reset":
        if not os.path.isfile(from_path):
            print("Error: Input file does not exist.")
            sys.exit(1)
        with open(from_path, "rb") as file:
            e_contents = file.read()

    lockdown = None
    for device in usbmux.list_devices():
        if device.is_usb:
            lockdown = create_using_usbmux(serial=device.serial)
            break

    if lockdown is None:
        print("Error: No connected device found.")
        sys.exit(1)

    if from_path != "Reset" and to_path == "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist":
        handle_special_plist(from_path, lockdown)

    try:
        restore_file(contents=e_contents, backup_path=backup_path, to_path=to_path, lockdown=lockdown)
    except PyMobileDevice3Exception as e:
        handle_exception(e, lockdown)
    except Exception as e:
        print(traceback.format_exc())


def handle_special_plist(from_path, lockdown):
    key_mapping = {
        "mZfUC7qo4pURNhyMHZ62RQ": "BuildVersion",
        "h9jDsbgj7xIVeIQ8S3/X3Q": "ProductType",
        "qNNddlUK+B/YlooNoymwgA": "ProductVersion",
        "LeSRsiLoJCMhjn6nd6GWbQ": "FirmwareVersion"
    }
    
    with open(from_path, 'rb') as fp:
        plist = plistlib.load(fp)
        all_values = lockdown.all_values

        for plist_key, value_key in key_mapping.items():
            plist_value = plist.get("CacheExtra", {}).get(plist_key, "N/A")
            all_value = all_values.get(value_key, "N/A")

            if plist_value != all_value:
                print("You might be using com.apple.MobileGestalt.plist of another device.")
                sys.exit(1)


def handle_exception(exception, lockdown):
    if "Find My" in str(exception):
        print("Find My must be disabled in order to use this tool.")
        print("Disable Find My from Settings (Settings -> [Your Name] -> Find My) and then try again.")
    elif "crash_on_purpose" not in str(exception):
        with DiagnosticsService(lockdown) as mb:
            mb.restart()
        raise exception
    else:
        print("Success. Rebooting your device...")
        with DiagnosticsService(lockdown) as mb:
            mb.restart()
        print("Remember to turn Find My back on!")

if __name__ == "__main__":
    main()
