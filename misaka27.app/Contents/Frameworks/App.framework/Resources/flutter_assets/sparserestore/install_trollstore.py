import os
import sys
import urllib.parse
import traceback
from pymobiledevice3.services.installation_proxy import InstallationProxyService
from pymobiledevice3 import usbmux
from pymobiledevice3.lockdown import create_using_usbmux
from pymobiledevice3.exceptions import PyMobileDevice3Exception
from pymobiledevice3.services.diagnostics import DiagnosticsService
from exploit.restore import restore_file

def get_connected_usb_device():
    for device in usbmux.list_devices():
        if device.is_usb:
            lockdown = create_using_usbmux(serial=device.serial)
            return lockdown
    return None

def get_tips_app_path(lockdown):
    apps_json = InstallationProxyService(lockdown).get_apps(application_type="System", calculate_sizes=False)
    return apps_json.get("com.apple.tips", {}).get("Path", "")

def restart_device(lockdown):
    with DiagnosticsService(lockdown) as diagnostics:
        diagnostics.restart()

def restore_tips_app(from_path, to_path, lockdown):
    print(f"[Restore] {from_path} -> {to_path}")
    e_contents = open(from_path, "rb").read()
    restore_file(contents=e_contents, backup_path=os.path.dirname(to_path), to_path=to_path, lockdown=lockdown)

def handle_restore_exception(e, lockdown):
    if "Find My" in str(e):
        print("Find My must be disabled in order to use this tool.")
        print("Disable Find My from Settings (Settings -> [Your Name] -> Find My) and then try again.")
    elif "crash_on_purpose" not in str(e):
        restart_device(lockdown)
        raise e
    else:
        print("Installed TrollStore")
        print("Success. Rebooting your device...")
        restart_device(lockdown)
        print("Remember to turn Find My back on!")

def main():
    if len(sys.argv) != 2:
        print("Usage: install_trollstore.py <from_path>")
        sys.exit(1)
    try:
        lockdown = get_connected_usb_device()
        if lockdown is None:
            print("NoDeviceConnectedError")
            sys.exit()

        tips_path = get_tips_app_path(lockdown)
        if not tips_path:
            print("Tips app is not installed. Please try after downloading.")
            sys.exit()

        from_path = urllib.parse.unquote(sys.argv[1])
        to_path = f"{tips_path.replace('/private', '')}/Tips"

        restore_tips_app(from_path, to_path, lockdown)

    except PyMobileDevice3Exception as e:
        handle_restore_exception(e, lockdown)
    except Exception as e:
        print(traceback.format_exc())

if __name__ == "__main__":
    main()
