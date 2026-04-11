from exploit.restore import restore_files, FileToRestore
from pymobiledevice3.services.diagnostics import DiagnosticsService
from pymobiledevice3 import usbmux
from pymobiledevice3.lockdown import create_using_usbmux
import json, sys, plistlib, os

def main():
    if len(sys.argv) != 2:
        print("Usage: restore.py <write_json>")
        sys.exit(1)

    with open(sys.argv[1], 'r') as file:
        file_mappings = json.load(file)
    
    lockdown = None
    for device in usbmux.list_devices():
        if device.is_usb:
            lockdown = create_using_usbmux(serial=device.serial)
            break

    if lockdown is None:
        print("Error: No connected device found.")
        sys.exit(1)

    files_to_restore = []
    for mapping in file_mappings:
        if os.path.getsize(mapping['from']) != 3 and mapping['to'] == "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist":
            handle_special_plist(mapping['from'], lockdown)
        # sanitized_to = mapping['to'].replace('/', '%2F')
        files_to_restore.append(FileToRestore(fr=mapping['from'], to=mapping['to']))

    for file in files_to_restore:
        print(f'From: {file.fr}, To: {file.to}')

    try:
        restore_files(files=files_to_restore, reboot=True, lockdown_client=lockdown)
    except Exception as e:
        handle_exception(exception=e, lockdown=lockdown)
    finally:
        pass

def handle_special_plist(from_path, lockdown):
    key_mapping = {
        "mZfUC7qo4pURNhyMHZ62RQ": "BuildVersion",
        "/YYygAofPDbhrwToVsXdeA": "HardwareModel",
        "LeSRsiLoJCMhjn6nd6GWbQ": "FirmwareVersion"
    }
    
    with open(from_path, 'rb') as fp:
        plist = plistlib.load(fp)
        all_values = lockdown.all_values

        for plist_key, value_key in key_mapping.items():
            plist_value = plist.get("CacheExtra", {}).get(plist_key, "N/A")
            all_value = all_values.get(value_key, "N/A")

            if plist_value != all_value:
                print(f"WARNING: Mismatch detected for {value_key}. Plist={plist_value}, Device={all_value}.")
                print("Continuing anyway for iOS 26.4 compatibility...")


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