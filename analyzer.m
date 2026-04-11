#include <stdio.h>
#include <stdlib.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <dlfcn.h>
#include <string.h>
#include <mach-o/loader.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        const char *mgName = "/Library/Developer/CoreSimulator/Volumes/iOS_23E244/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.4.simruntime/Contents/Resources/RuntimeRoot/usr/lib/libMobileGestalt.dylib";
        void *handle = dlopen(mgName, RTLD_GLOBAL);
        if (!handle) {
            printf("Failed to dlopen\n");
            return 1;
        }

        const struct mach_header_64 *header = NULL;
        for (int i = 0; i < _dyld_image_count(); i++) {
            if (strstr(_dyld_get_image_name(i), "libMobileGestalt.dylib")) {
                header = (const struct mach_header_64 *)_dyld_get_image_header(i);
                break;
            }
        }
        
        if (!header) {
            printf("Header not found\n");
            return 1;
        }

        const char *mgKey = "mtrAoWJ3gsq+I90ZnQ0vQw";
        size_t textCStringSize;
        const char *textCStringSection = (const char *)getsectiondata(header, "__TEXT", "__cstring", &textCStringSize);
        long string_offset = -1;
        for (size_t size = 0; size < textCStringSize; size += strlen(textCStringSection + size) + 1) {
            if (!strncmp(mgKey, textCStringSection + size, strlen(mgKey))) {
                textCStringSection += size;
                string_offset = size;
                break;
            }
        }

        if (string_offset == -1) {
            printf("String not found\n");
            return 1;
        }

        size_t constSize;
        const uintptr_t *constSection = (const uintptr_t *)getsectiondata(header, "__AUTH_CONST", "__const", &constSize);
        if (!constSection) {
            constSection = (const uintptr_t *)getsectiondata(header, "__DATA_CONST", "__const", &constSize);
        }

        int found_idx = -1;
        for (int i = 0; i < constSize / sizeof(uintptr_t); i++) {
            if (constSection[i] == (uintptr_t)textCStringSection) {
                found_idx = i;
                constSection += i;
                break;
            }
        }

        if (found_idx == -1) {
            printf("Pointer not found\n");
            return 1;
        }

        printf("Found pointer at constSection[%d]\n", found_idx);
        
        uint8_t *bytes = (uint8_t *)constSection;
        printf("Dumping bytes around struct:\n");
        for (int i = 0; i < 256; i+=16) {
            printf("%02x: ", i);
            for (int j = 0; j < 16; j++) {
                printf("%02x ", bytes[i+j]);
            }
            printf("\n");
        }
    }
    return 0;
}
