//
//  ToxFriend.h
//  Antidote
//
//  Created by Dmitry Vorobyov on 19.07.14.
//  Copyright (c) 2014 dvor. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ToxFriend : NSObject

@property (assign, nonatomic) int32_t id;

- (BOOL)isEqual:(id)object;
- (NSUInteger)hash;

@end
