//
//  AvailablityCell.h
//  BLEChat
//
//  Created by AjayKumar.Pasumarthi on 8/24/15.
//  Copyright © 2015 AjayKumar.Pasumarthi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>

@interface AvailablityCell : UITableViewCell

@property(nonatomic,strong)MCPeerID *peerId;
@property(nonatomic,assign)BOOL hasUnread;
@property (weak, nonatomic) IBOutlet UILabel *lblName;


@end
