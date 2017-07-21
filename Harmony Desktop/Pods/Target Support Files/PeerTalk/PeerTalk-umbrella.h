#ifdef __OBJC__
#import <Cocoa/Cocoa.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "Peertalk.h"
#import "PTChannel.h"
#import "PTPrivate.h"
#import "PTProtocol.h"
#import "PTUSBHub.h"

FOUNDATION_EXPORT double PeerTalkVersionNumber;
FOUNDATION_EXPORT const unsigned char PeerTalkVersionString[];

