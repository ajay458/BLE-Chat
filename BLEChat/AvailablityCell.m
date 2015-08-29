//
//  AvailablityCell.m
//  BLEChat
//
//  Created by AjayKumar.Pasumarthi on 8/24/15.
//  Copyright © 2015 AjayKumar.Pasumarthi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AvailablityCell.h"
@interface AvailablityCell()

@property (weak, nonatomic) IBOutlet UILabel *lblLastSeen;

@end


@implementation AvailablityCell

- (void)setPeerId:(MCPeerID *)peerId
{
    _peerId = peerId;
    
}

@end
