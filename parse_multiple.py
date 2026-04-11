import struct

def fetch_ptrs():
    filepath = "/Library/Developer/CoreSimulator/Volumes/iOS_23E244/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.4.simruntime/Contents/Resources/RuntimeRoot/usr/lib/libMobileGestalt.dylib"
    with open(filepath, 'rb') as f:
        data = f.read()

    # The __DATA_CONST __const section starts at 296792, size 0x5c370
    start = 296792
    size = 0x5c370
    
    # However we know the pointer is encoded as DYLD chained fixups or rebases.
    # WAIT! The C code reads `constSection[i]` in memory! In memory, it IS resolved to the actual address.
    pass
