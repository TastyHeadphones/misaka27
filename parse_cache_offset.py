import struct

def fetch_cache_offset():
    filepath = "/Library/Developer/CoreSimulator/Volumes/iOS_23E244/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.4.simruntime/Contents/Resources/RuntimeRoot/usr/lib/libMobileGestalt.dylib"
    with open(filepath, 'rb') as f:
        data = f.read()

    # The pointer is at file offset 0x72C70
    ptr_offset = 0x72C70
    
    # Try multiple struct offsets around 0x9a
    print("Dumping uint16_t offsets from struct pointer 0x72C70:")
    for i in range(0x80, 0xb0, 2):
        val = struct.unpack_from("<H", data, ptr_offset + i)[0]
        # We know Cache offset for DeviceClassNumber should be 248954 ... wait!
        # NO! 248954 is the string offset of "DeviceClassNumber"!
        # The cache offset is a completely different number!! 
        # But wait, what does `((uint16_t *)constSection)[0x9a / 2] << 3` calculate?
        # In 26.0, the value at 0x9a was the un-shifted cache offset!
        print(f"+0x{i:02x}: {val} (hex: 0x{val:04x}, shifted<<3: {val << 3})")

fetch_cache_offset()
