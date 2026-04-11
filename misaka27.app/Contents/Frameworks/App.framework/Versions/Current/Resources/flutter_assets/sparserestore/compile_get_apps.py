import PyInstaller.__main__

args = [
    'get_apps.py',
    '--name=misaka26-get_apps',
    '--onedir',
    '--hidden-import=zeroconf',
    '--hidden-import=zeroconf._utils.ipaddress',
    '--hidden-import=zeroconf._handlers.answers'
]

PyInstaller.__main__.run(args)