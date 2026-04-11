//
//  trollpad_patcher.m
//  TrollPad Patcher
//
//  Patches MobileGestalt cache to change DeviceClass from iPhone to iPad
//

#include <stdio.h>
#include <stdlib.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <dlfcn.h>
#include <string.h>

// Find offset for a given MobileGestalt key
off_t find_offset(const char* mgKey) {
    const struct mach_header_64 *header = NULL;
    const char *mgName = "/usr/lib/libMobileGestalt.dylib";
    dlopen(mgName, RTLD_GLOBAL);

    for (int i = 0; i < _dyld_image_count(); i++) {
        if (!strncmp(mgName, _dyld_get_image_name(i), strlen(mgName))) {
            header = (const struct mach_header_64 *)_dyld_get_image_header(i);
            break;
        }
    }
    
    assert(header);

    // Locate the obfuscated key in __TEXT __cstring
    size_t textCStringSize;
    const char *textCStringSection = (const char *)getsectiondata(header, "__TEXT", "__cstring", &textCStringSize);
    for (size_t size = 0; size < textCStringSize; size += strlen(textCStringSection + size) + 1) {
        if (!strncmp(mgKey, textCStringSection + size, strlen(mgKey))) {
            textCStringSection += size;
            break;
        }
    }

    // Locate the unknown struct in __AUTH_CONST or __DATA_CONST
    size_t constSize;
    const uintptr_t *constSection = (const uintptr_t *)getsectiondata(header, "__AUTH_CONST", "__const", &constSize);
    if (!constSection) {
        constSection = (const uintptr_t *)getsectiondata(header, "__DATA_CONST", "__const", &constSize);
    }

    for (int i = 0; i < constSize / sizeof(uintptr_t); i++) {
        if (constSection[i] == (uintptr_t)textCStringSection) {
            constSection += i;
            break;
        }
    }

    // Calculate the offset (shift left by 3 bits)
    off_t offset = (off_t)((uint16_t *)constSection)[0x9a / 2] << 3;
    return offset;
}

void patch_device_class(unsigned char *buffer, size_t size, BOOL enableIPad) {
    if (!buffer || size == 0) {
        fprintf(stderr, "Invalid buffer or size.\n");
        return;
    }

    // DeviceClassNumber key: mtrAoWJ3gsq+I90ZnQ0vQw
    off_t offset = find_offset("mtrAoWJ3gsq+I90ZnQ0vQw");
    
    if (offset != -1 && offset < size) {
        // DeviceClassNumber values:
        // 1 = iPhone
        // 3 = iPad
        if (enableIPad) {
            buffer[offset] = 0x03; // Set to iPad
            NSLog(@"✓ Patched DeviceClassNumber to iPad (0x03) at offset: %#05llx", (long long)offset);
        } else {
            buffer[offset] = 0x01; // Set to iPhone
            NSLog(@"✓ Patched DeviceClassNumber to iPhone (0x01) at offset: %#05llx", (long long)offset);
        }
    } else {
        NSLog(@"✗ Could not find DeviceClassNumber offset or offset out of range.");
    }
}

@interface TrollPadPatcher : NSObject
- (void)modifyPlistAtPath:(NSString *)path enableIPad:(BOOL)enableIPad;
@end

@implementation TrollPadPatcher

- (NSData *)modifyCacheData:(NSData *)cacheData enableIPad:(BOOL)enableIPad {
    if (!cacheData || [cacheData length] == 0) {
        NSLog(@"Invalid or empty cache data.");
        return cacheData;
    }

    // Convert NSData to a mutable buffer
    NSUInteger size = [cacheData length];
    unsigned char *buffer = malloc(size);
    if (!buffer) {
        NSLog(@"Memory allocation failed.");
        return cacheData;
    }
    [cacheData getBytes:buffer length:size];

    // Patch the DeviceClassNumber
    patch_device_class(buffer, size, enableIPad);

    // Convert the modified buffer back to NSData
    NSData *modifiedData = [NSData dataWithBytes:buffer length:size];

    // Free the buffer
    free(buffer);

    return modifiedData;
}

- (void)modifyPlistAtPath:(NSString *)path enableIPad:(BOOL)enableIPad {
    // Load plist file
    NSMutableDictionary *plistDict = [[NSMutableDictionary alloc] initWithContentsOfFile:path];
    if (!plistDict) {
        NSLog(@"Failed to load plist at path: %@", path);
        return;
    }

    // Check CacheExtra for DeviceClass validation
    NSDictionary *cacheExtra = plistDict[@"CacheExtra"];
    if (cacheExtra && [cacheExtra isKindOfClass:[NSDictionary class]]) {
        NSString *deviceClass = cacheExtra[@"+3Uf0Pm5F8Xy7Onyvko0vA"];
        if (deviceClass && [deviceClass isKindOfClass:[NSString class]]) {
            NSLog(@"Current DeviceClass in CacheExtra: %@", deviceClass);
            
            if (enableIPad && ![deviceClass isEqualToString:@"iPhone"]) {
                NSLog(@"⚠️  WARNING: DeviceClass is not iPhone. TrollPad may not work correctly!");
            }
        }
    }

    // Extract CacheData key
    NSData *cacheData = plistDict[@"CacheData"];
    if (!cacheData || ![cacheData isKindOfClass:[NSData class]]) {
        NSLog(@"CacheData key is missing or invalid in plist.");
        return;
    }

    // Modify CacheData
    NSData *modifiedData = [self modifyCacheData:cacheData enableIPad:enableIPad];

    // Update plist with modified data
    plistDict[@"CacheData"] = modifiedData;

    // Save back to file
    if ([plistDict writeToFile:path atomically:YES]) {
        NSLog(@"✓ Successfully modified and saved plist.");
        if (enableIPad) {
            NSLog(@"\n⚠️  IMPORTANT: DO NOT TURN OFF 'SHOW DOCK' IN STAGE MANAGER!");
            NSLog(@"    Disabling dock while in landscape may cause bootloop.\n");
        }
    } else {
        NSLog(@"✗ Failed to save plist at path: %@", path);
    }
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 2 || argc > 3) {
            NSLog(@"Usage: trollpad_patcher <path_to_plist> [enable|disable]");
            NSLog(@"  enable  - Change DeviceClass to iPad (default)");
            NSLog(@"  disable - Change DeviceClass back to iPhone");
            return 1;
        }
        
        NSString *plistPath = [NSString stringWithUTF8String:argv[1]];
        BOOL enableIPad = YES; // Default to enabling iPad mode
        
        if (argc == 3) {
            NSString *action = [NSString stringWithUTF8String:argv[2]];
            if ([action isEqualToString:@"disable"]) {
                enableIPad = NO;
            }
        }
        
        NSLog(@"═══════════════════════════════════════════");
        NSLog(@"  TrollPad Patcher");
        NSLog(@"  Mode: %@", enableIPad ? @"Enable iPad" : @"Disable iPad");
        NSLog(@"═══════════════════════════════════════════\n");
        
        TrollPadPatcher *patcher = [[TrollPadPatcher alloc] init];
        [patcher modifyPlistAtPath:plistPath enableIPad:enableIPad];
        
        NSLog(@"\n═══════════════════════════════════════════");
        NSLog(@"  Patching complete!");
        NSLog(@"═══════════════════════════════════════════");
    }
    return 0;
}