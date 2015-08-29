//
//  ChatInfo.h
//  BLEChat
//
//  Created by AjayKumar.Pasumarthi on 8/29/15.
//  Copyright © 2015 AjayKumar.Pasumarthi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ChatInfo : NSObject

@property(nonatomic,strong)NSString *message;
@property(nonatomic,assign)BOOL isReciever;
@property(nonatomic,strong)NSDate *messagedate;//as of now not using this
@property(nonatomic,strong)NSValue *messageSize;
@property(nonatomic,assign)BOOL isUnread;

@end
