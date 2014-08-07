//
//  NSData+GBK.m
//  Swift Photos
//
//  Created by Venj Chu on 14/8/6.
//  Copyright (c) 2014年 Venj Chu. All rights reserved.
//

#import "NSData+GBK.h"

@implementation NSData(GBK)
- (NSString *)stringFromGBKData {
    NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    return [[NSString alloc] initWithData:self encoding:encoding];
}
@end
