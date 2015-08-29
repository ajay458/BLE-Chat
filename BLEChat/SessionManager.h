//
//  SessionManager.h
//  BLEChat
//
//  Created by AjayKumar.Pasumarthi on 8/25/15.
//  Copyright © 2015 AjayKumar.Pasumarthi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>

@protocol SessionManagerDelegate <NSObject>

// Session changed state - connecting, connected and disconnected peers changed
- (void)sessionDidChangeState;
- (void)didReciveData:(NSData*)data fromPeer:(MCPeerID*)peerID;

@end


@interface SessionManager : NSObject

@property (nonatomic, readonly) NSArray *connectedPeers;
@property (nonatomic, readonly) NSArray *connectingPeers;
@property (nonatomic, readonly) NSArray *disconnectedPeers;
@property (nonatomic, readonly) NSString *displayName;


// Helper method for human readable printing of MCSessionState. This state is per peer.
- (NSString *)stringForPeerConnectionState:(MCSessionState)state;

+ (instancetype)sharedManager;
- (void)initiateSessionWithDisplayName:(NSString*)displayName andDelegate:(id<SessionManagerDelegate>)delegate;
- (void)destroyAllInstances;
//- (instancetype)initWithDisplayName:(NSString*)displayName andDelegate:(id<SessionManagerDelegate>)delegate;

- (void)sendData:(NSData*)data toPeer:(MCPeerID*)peerId;

@end
