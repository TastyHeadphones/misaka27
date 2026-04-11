import struct
def fetch_cache_offset():
    filepath = "/Library/Developer/CoreSimulator/Volumes/iOS_23E244/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.4.simruntime/Contents/Resources/RuntimeRoot/usr/lib/libMobileGestalt.dylib"
    with open(filepath, 'rb') as f:
        data = f.read()

    ptr_offset = 0x70C90
    print("Dumping uint16_t offsets from struct pointer 0x70C90:")
    for i in range(0x80, 0xb0, 2):
        val = struct.unpack_from("<H", data, ptr_offset + i)[0]
        print(f"+0x{i:02x}: {val} (hex: 0x{val:04x}, shifted<<3: {val << 3})")

fetch_cache_offset()
