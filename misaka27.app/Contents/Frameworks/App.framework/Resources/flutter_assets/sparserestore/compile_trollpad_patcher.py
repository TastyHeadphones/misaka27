import PyInstaller.__main__

args = [
    'trollpad_patcher.py',
    '--name=misaka26-trollpad_patcher',
    '--onedir'
]

PyInstaller.__main__.run(args)