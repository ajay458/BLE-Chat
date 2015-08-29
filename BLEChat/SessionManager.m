//
//  SessionManager.m
//  BLEChat
//
//  Created by AjayKumar.Pasumarthi on 8/25/15.
//  Copyright © 2015 AjayKumar.Pasumarthi. All rights reserved.
//

#import "SessionManager.h"

@interface SessionManager()<MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate>
@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCSession *session;
@property (nonatomic, strong) MCNearbyServiceAdvertiser *serviceAdvertiser;
@property (nonatomic, strong) MCNearbyServiceBrowser *serviceBrowser;

// Connected peers are stored in the MCSession
// Manually track connecting and disconnected peers
@property (nonatomic, strong) NSMutableOrderedSet *connectingPeersOrderedSet;
@property (nonatomic, strong) NSMutableOrderedSet *disconnectedPeersOrderedSet;
@property(nonatomic,weak)id<SessionManagerDelegate>delegate;


@end

@implementation SessionManager
static NSString * const kMCSessionServiceType = @"mcsessionp2p";


+ (instancetype)sharedManager
{
    static SessionManager *sharedInstance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}


- (void)initiateSessionWithDisplayName:(NSString*)displayName andDelegate:(id<SessionManagerDelegate>)delegate
{
    self.delegate = delegate;
    
    self.peerID = [[MCPeerID alloc] initWithDisplayName:displayName];
    
    self.connectingPeersOrderedSet = [[NSMutableOrderedSet alloc] init];
    self.disconnectedPeersOrderedSet = [[NSMutableOrderedSet alloc] init];
    
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    
    // Register for notifications
    [defaultCenter addObserver:self
                      selector:@selector(startServices)
                          name:UIApplicationWillEnterForegroundNotification
                        object:nil];
    
    [defaultCenter addObserver:self
                      selector:@selector(stopServices)
                          name:UIApplicationDidEnterBackgroundNotification
                        object:nil];
    
    [self startServices];
    
    _displayName = self.session.myPeerID.displayName;
    
}

- (void)destroyAllInstances
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _session.delegate = nil;
    _serviceAdvertiser.delegate = nil;
    _serviceBrowser.delegate = nil;

}


- (void)startServices
{
    [self setupSession];
    [self.serviceAdvertiser startAdvertisingPeer];
    [self.serviceBrowser startBrowsingForPeers];
}
- (void)stopServices
{
    [self.serviceBrowser stopBrowsingForPeers];
    [self.serviceAdvertiser stopAdvertisingPeer];
    [self teardownSession];
}

- (void)teardownSession
{
    [self.session disconnect];
    [self.connectingPeersOrderedSet removeAllObjects];
    [self.disconnectedPeersOrderedSet removeAllObjects];
}


- (void)setupSession
{
    // Create the session that peers will be invited/join into.
    _session = [[MCSession alloc] initWithPeer:self.peerID];
    self.session.delegate = self;
    
    // Create the service advertiser
    _serviceAdvertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.peerID
                                                           discoveryInfo:nil
                                                             serviceType:kMCSessionServiceType];
    self.serviceAdvertiser.delegate = self;
    
    // Create the service browser
    _serviceBrowser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.peerID
                                                       serviceType:kMCSessionServiceType];
    self.serviceBrowser.delegate = self;
}

- (void)dealloc
{

}


- (void)updateDelegate
{
    [self.delegate sessionDidChangeState];
}

- (NSString *)stringForPeerConnectionState:(MCSessionState)state
{
    switch (state) {
        case MCSessionStateConnected:
            return @"Connected";
            
        case MCSessionStateConnecting:
            return @"Connecting";
            
        case MCSessionStateNotConnected:
            return @"Not Connected";
    }
}


#pragma mark - Override property accessors

- (NSArray *)connectedPeers
{
    return self.session.connectedPeers;
}

- (NSArray *)connectingPeers
{
    return [self.connectingPeersOrderedSet array];
}

- (NSArray *)disconnectedPeers
{
    return [self.disconnectedPeersOrderedSet array];
}


#pragma mark - MCSessionDelegate protocol conformance

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    NSLog(@"Peer [%@] changed state to %@", peerID.displayName, [self stringForPeerConnectionState:state]);
    
    switch (state)
    {
        case MCSessionStateConnecting:
        {
            [self.connectingPeersOrderedSet addObject:peerID];
            [self.disconnectedPeersOrderedSet removeObject:peerID];
            break;
        }
            
        case MCSessionStateConnected:
        {
            [self.connectingPeersOrderedSet removeObject:peerID];
            [self.disconnectedPeersOrderedSet removeObject:peerID];
            break;
        }
            
        case MCSessionStateNotConnected:
        {
            [self.connectingPeersOrderedSet removeObject:peerID];
            [self.disconnectedPeersOrderedSet addObject:peerID];
            break;
        }
    }
    
    [self updateDelegate];
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    // Decode the incoming data to a UTF8 encoded string
    NSString *receivedMessage = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSLog(@"didReceiveData %@ from %@", receivedMessage, peerID.displayName);
    [self.delegate didReciveData:data fromPeer:peerID];
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
    NSLog(@"didStartReceivingResourceWithName [%@] from %@ with progress [%@]", resourceName, peerID.displayName, progress);
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
    NSLog(@"didFinishReceivingResourceWithName [%@] from %@", resourceName, peerID.displayName);
    
    // If error is not nil something went wrong
    if (error)
    {
        NSLog(@"Error [%@] receiving resource from %@ ", [error localizedDescription], peerID.displayName);
    }
    else
    {
        // No error so this is a completed transfer.  The resources is located in a temporary location and should be copied to a permenant location immediately.
        // Write to documents directory
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *copyPath = [NSString stringWithFormat:@"%@/%@", [paths firstObject], resourceName];
        if (![[NSFileManager defaultManager] copyItemAtPath:[localURL path] toPath:copyPath error:nil])
        {
            NSLog(@"Error copying resource to documents directory");
        }
        else
        {
            // Get a URL for the path we just copied the resource to
            NSURL *url = [NSURL fileURLWithPath:copyPath];
            NSLog(@"url = %@", url);
        }
    }
}

// Streaming API not utilized in this sample code
- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
    NSLog(@"didReceiveStream %@ from %@", streamName, peerID.displayName);
}



#pragma mark - MCNearbyServiceBrowserDelegate protocol conformance

// Found a nearby advertising peer
- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info
{
    NSString *remotePeerName = peerID.displayName;
    
    NSLog(@"Browser found %@", remotePeerName);
    
    MCPeerID *myPeerID = self.session.myPeerID;
    
    BOOL shouldInvite = ([myPeerID.displayName compare:remotePeerName] == NSOrderedDescending);
    
    if (shouldInvite)
    {
        NSLog(@"Inviting %@", remotePeerName);
        [browser invitePeer:peerID toSession:self.session withContext:nil timeout:30.0];
    }
    else
    {
        NSLog(@"Not inviting %@", remotePeerName);
    }
    
    [self updateDelegate];
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID
{
    NSLog(@"lostPeer %@", peerID.displayName);
    
    [self.connectingPeersOrderedSet removeObject:peerID];
    [self.disconnectedPeersOrderedSet addObject:peerID];
    
    [self updateDelegate];
}

- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error
{
    NSLog(@"didNotStartBrowsingForPeers: %@", error);
}

#pragma mark - MCNearbyServiceAdvertiserDelegate protocol conformance

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void(^)(BOOL accept, MCSession *session))invitationHandler
{
    NSLog(@"didReceiveInvitationFromPeer %@", peerID.displayName);
    
    invitationHandler(YES, self.session);
    
    [self.connectingPeersOrderedSet addObject:peerID];
    [self.disconnectedPeersOrderedSet removeObject:peerID];
    
    [self updateDelegate];
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error
{
    NSLog(@"didNotStartAdvertisingForPeers: %@", error);
}


- (void)sendData:(NSData*)data toPeer:(MCPeerID*)peerId
{
    NSError *transferError = nil;
    [self.session sendData:data toPeers:@[peerId] withMode:MCSessionSendDataReliable error:&transferError];
}

@end