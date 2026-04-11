import PyInstaller.__main__

args = [
    'install_trollstore.py',
    '--name=misaka26-install_trollstore',
    '--onedir',
    '--hidden-import=zeroconf',
    '--hidden-import=zeroconf._utils.ipaddress',
    '--hidden-import=zeroconf._handlers.answers'
]

PyInstaller.__main__.run(args)