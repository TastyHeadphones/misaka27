import PyInstaller.__main__

args = [
    'json_restore.py',
    '--name=misaka26-json_restore',
    '--onedir',
    '--hidden-import=zeroconf',
    '--hidden-import=zeroconf._utils.ipaddress',
    '--hidden-import=zeroconf._handlers.answers'
]

PyInstaller.__main__.run(args)