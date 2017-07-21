//
//  Conversion.m
//  Harmony iOS
//
//  Created by Frederick Morlock on 7/20/17.
//  Copyright © 2017 Frederick Morlock. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PTExampleProtocol.h"
#import "PeerTalk/PTChannel.h"

@interface PayloadConverter : NSObject
-(NSString *)convertToString:(PTData*) payload;
@end

@implementation PayloadConverter : NSObject

-(NSString *)convertToString:(PTData*) payload{
    PTExampleTextFrame *textFrame = (PTExampleTextFrame*)payload.data;
    textFrame->length = ntohl(textFrame->length);
    NSString *message = [[NSString alloc] initWithBytes:textFrame->utf8text length:textFrame->length encoding:NSUTF8StringEncoding];
    
    return message;
}

@end

