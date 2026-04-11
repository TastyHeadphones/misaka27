import PyInstaller.__main__

args = [
    'gestalt_restore.py',
    '--name=misaka26-gestalt_restore',
    '--onedir',
    '--hidden-import=zeroconf',
    '--hidden-import=zeroconf._utils.ipaddress',
    '--hidden-import=zeroconf._handlers.answers',
    # readchar は importlib.metadata からバージョン情報を取得するため、
    # PyInstaller で freeze した際にメタデータも同梱する必要がある
    '--copy-metadata=readchar',
    # 念のため本体も明示的に hidden-import に追加
    '--hidden-import=readchar',
]

PyInstaller.__main__.run(args)