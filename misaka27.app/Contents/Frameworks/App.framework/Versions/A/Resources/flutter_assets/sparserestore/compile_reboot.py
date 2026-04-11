import PyInstaller.__main__

args = [
    'reboot.py',
    '--name=misaka26-reboot',
    '--onedir',
    '--hidden-import=zeroconf',
    '--hidden-import=zeroconf._utils.ipaddress',
    '--hidden-import=zeroconf._handlers.answers'
]

PyInstaller.__main__.run(args)