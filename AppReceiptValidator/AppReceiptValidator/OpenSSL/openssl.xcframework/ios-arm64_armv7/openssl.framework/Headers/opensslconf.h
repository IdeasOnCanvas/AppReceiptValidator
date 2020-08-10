/*
 * Building OpenSSL for the different architectures of all iOS and tvOS devices requires different settings.
 * In order to be able to use assembly code on all devices, the choice was made to keep optimal settings for all
 * devices and use this intermediate header file to use the proper opensslconf.h file for each architecture.

 * See also https://github.com/x2on/OpenSSL-for-iPhone/issues/126 and referenced pull requests
 */

#include <TargetConditionals.h>

#if TARGET_OS_IOS && TARGET_OS_SIMULATOR && TARGET_CPU_X86_64
#include "opensslconf_ios_x86_64.h"
#elif TARGET_OS_IOS && TARGET_OS_SIMULATOR && TARGET_CPU_ARM64
#include "opensslconf_ios_arm64.h"
#elif TARGET_OS_IOS && TARGET_OS_EMBEDDED && TARGET_CPU_ARM && !defined(__ARM_ARCH_7S__)
#include "opensslconf_ios_armv7.h"
#elif TARGET_OS_IOS && TARGET_OS_EMBEDDED && TARGET_CPU_ARM64
#include "opensslconf_ios_arm64.h"
#elif (TARGET_OS_MACCATALYST || (TARGET_OS_IOS && TARGET_OS_SIMULATOR)) && TARGET_CPU_X86_64
#include "opensslconf_catalyst_x86_64.h"
#elif TARGET_OS_TV && TARGET_OS_SIMULATOR && TARGET_CPU_X86_64
#include "opensslconf_tvos_x86_64.h"
#elif TARGET_OS_TV && TARGET_OS_EMBEDDED && TARGET_CPU_ARM64
#include "opensslconf_tvos_arm64.h"
#elif TARGET_OS_OSX && TARGET_CPU_X86_64
#include "opensslconf_macos_x86_64.h"
#elif TARGET_OS_OSX && TARGET_CPU_ARM64
#include "opensslconf_macos_arm64.h"
#elif TARGET_OS_WATCHOS && TARGET_OS_EMBEDDED && TARGET_CPU_ARMV7K
#include "opensslconf_watchos_armv7k.h"
#elif TARGET_OS_WATCHOS && TARGET_OS_EMBEDDED && TARGET_CPU_ARM64_32
#include "opensslconf_watchos_arm64_32.h"
#elif TARGET_OS_SIMULATOR && TARGET_CPU_X86 || TARGET_OS_EMBEDDED
#include "opensslconf_watchos_i386.h"
#else
# error Unable to determine target or target not included in OpenSSL build
#endif
