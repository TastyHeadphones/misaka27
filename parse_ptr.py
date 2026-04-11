import struct

def find_ptr():
    filepath = "/Library/Developer/CoreSimulator/Volumes/iOS_23E244/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.4.simruntime/Contents/Resources/RuntimeRoot/usr/lib/libMobileGestalt.dylib"
    with open(filepath, 'rb') as f:
        data = f.read()

    ptr = struct.pack("<Q", 0x36E7F)
    offset = data.find(ptr)
    if offset == -1:
        print("Pointer not found")
        return
    print(f"Pointer found at file offset: {offset} (0x{offset:x})")

    # The C code reads `uint16_t` at offset `0x9a` relative to this pointer's location?
    # Wait, `(uint16_t *)constSection` where constSection points to the found pointer.
    # So it casts the pointer's location to `uint16_t *`, and reads index `0x9a / 2`.
    # Index `0x9a / 2` = 77.
    # So byte offset `0x9a` from `offset`.

    val = struct.unpack_from("<H", data, offset + 0x9a)[0]
    print(f"Value at +0x9a: {val} (0x{val:x})")
    
    # We also want to dump surrounding bytes to verify the struct layout.
    print("Dumping 0x80 to 0xa0:")
    for i in range(0x80, 0xb0, 2):
        v = struct.unpack_from("<H", data, offset + i)[0]
        print(f"+0x{i:02x}: {v} (0x{v:04x})")

find_ptr()
