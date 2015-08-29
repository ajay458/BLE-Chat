//
//  ViewController.m
//  BLEChat
//
//  Created by AjayKumar.Pasumarthi on 8/24/15.
//  Copyright © 2015 AjayKumar.Pasumarthi. All rights reserved.
//

#import "ViewController.h"
#import "Constants.h"
#import "AvailablityCell.h"
#import "SessionManager.h"
#import "ChatController.h"
#import "ChatInfo.h"


typedef enum {
    BLEChatDisconnected,
    BLEChatConnected
} BLEChatStatus;

@interface ViewController ()<UITableViewDataSource,UITableViewDataSource,SessionManagerDelegate,ChatControllerDelegate>

@property(nonatomic,assign)BLEChatStatus chatStatus;
@property(nonatomic,weak)IBOutlet UITableView *availableList;
@property(nonatomic,weak)IBOutlet UILabel *welcomeLabel;
@property(nonatomic,weak)IBOutlet UITextField *userNameTextField;
@property(nonatomic,weak)IBOutlet UIButton *btnConnect;
@property(nonatomic,strong)SessionManager *sessionManager;
@property (strong, nonatomic) ChatController * chatController;
@property(nonatomic,assign)NSInteger peerIndex;
@property(nonatomic,strong)NSMutableDictionary *messagesDict;//we can store in file later stage

/*{@"displayName1":
 [
 @"Message1":{
 
 },
 
 ],
 
 }*/


- (IBAction)chatAction:(id)sender;


@end

@implementation ViewController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.title = @"BLE-Chat";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.messagesDict = [[NSMutableDictionary alloc] initWithCapacity:1];
    // Do any additional setup after loading the view, typically from a nib.
    [self.availableList registerNib:[UINib nibWithNibName:@"AvailablityCell" bundle:nil] forCellReuseIdentifier:@"AvailablityCell"];
    
    [self adjustComponentAccordingToChatStatus];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Suport methods

- (IBAction)chatAction:(id)sender
{
    UIButton *statusChangebtn = (UIButton*)sender;
    if(!statusChangebtn.isSelected)//disconnected state
    {
        self.chatStatus = BLEChatConnected;
        [statusChangebtn setSelected:YES];
        self.sessionManager = [SessionManager sharedManager];
        [self.sessionManager initiateSessionWithDisplayName:self.userNameTextField.text andDelegate:self];
        [self.view resignFirstResponder];
    }
    else // connected state
    {
        self.chatStatus = BLEChatDisconnected;
        [statusChangebtn setSelected:NO];
        //self.sessionManager = nil;
        [self.sessionManager destroyAllInstances];
    }
    [self adjustComponentAccordingToChatStatus];
}

- (void)adjustComponentAccordingToChatStatus
{
    if(self.chatStatus == BLEChatDisconnected)
    {
        [self.availableList setHidden:YES];
        [self.welcomeLabel setHidden:YES];
        [self.userNameTextField setHidden:NO];
        [self.btnConnect setTitle:@"Connect" forState:UIControlStateNormal];
        [self.btnConnect setTitle:@"Connect" forState:UIControlStateHighlighted];
        [self.btnConnect setTitle:@"Connect" forState:UIControlStateSelected];
    }
    else if (self.chatStatus == BLEChatConnected)
    {
        [self.availableList setHidden:NO];
        [self.welcomeLabel setHidden:NO];
        [self.userNameTextField setHidden:YES];
        [self.btnConnect setTitle:@"DisConnect" forState:UIControlStateNormal];
        [self.btnConnect setTitle:@"DisConnect" forState:UIControlStateHighlighted];
        [self.btnConnect setTitle:@"DisConnect" forState:UIControlStateSelected];
    }
}


- (void)touchesBegan:(nonnull NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event
{
    [self.view endEditing:YES];
}
//- (SessionManager*)sessionManager
//{
//    return [SessionManager sharedManager];
//}

#pragma mark UITableViewDataSource

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSLog(@"[[self.sessionManager connectedPeers] count]  =%lu",(unsigned long)[[self.sessionManager connectedPeers] count]);
    NSLog(@"[[self.sessionManager connectingPeers] count]  =%lu",(unsigned long)[[self.sessionManager connectingPeers] count]);
    NSLog(@"[[self.sessionManager disconnectedPeers] count]  =%lu",(unsigned long)[[self.sessionManager disconnectedPeers] count]);
    return [[self.sessionManager connectedPeers] count];
}

- (NSString*)tableView:(nonnull UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @"Available Friends For Chat";
}

- (UITableViewCell*)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"AvailablityCell";
    AvailablityCell *cell = (AvailablityCell*)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    MCPeerID *peerID = [[self.sessionManager connectedPeers] objectAtIndex:indexPath.row];

    cell.peerId =peerID;
    NSArray *chatInfoArray = self.messagesDict[peerID.displayName];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.isUnread==%@",@(YES)];
    NSArray *unReadArray = [chatInfoArray filteredArrayUsingPredicate:predicate];
    NSString *displayName = nil;
    if(unReadArray.count>0)
    {
        displayName = [peerID.displayName stringByAppendingFormat:@"(%ld)",(long)unReadArray.count];
    }
    else
    {
        displayName = peerID.displayName;
    }
    cell.textLabel.text = displayName;
    
    return cell;
}


- (void)sessionDidChangeState
{
    __weak ViewController *weakSelf = self;
    // Ensure UI updates occur on the main queue.
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf.availableList reloadData];
    });
}

- (void)didReciveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    NSString *content = [NSString stringWithUTF8String:[data bytes]];
    NSString *displayName = [peerID displayName];
    ChatInfo *newChatInfo = [[ChatInfo alloc] init];
    newChatInfo.message = content;
    newChatInfo.messagedate = [NSDate date];
    newChatInfo.isReciever = YES;
    [self addChatInfo:newChatInfo forDisplayName:displayName];
    
    
    __weak ViewController *weakSelf = self;

    dispatch_async(dispatch_get_main_queue(), ^{
        if(weakSelf.chatController)
        {
            [_chatController addMessageObject:newChatInfo];
        }
        else
        {
            newChatInfo.isUnread = YES;
            [weakSelf.availableList reloadData];
            
        }
    });
    
    
}

#pragma mark UITableViewDelegate


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    if (!_chatController) _chatController = [ChatController new];
    _chatController.delegate = self;
    AvailablityCell *cell = (AvailablityCell*)[tableView cellForRowAtIndexPath:indexPath];
    _chatController.title = cell.peerId.displayName ;

    _chatController.peerId =cell.peerId;
    _chatController.opponentImg = [UIImage imageNamed:@"tempUser.png"];
    _chatController.messagesArray = [self.messagesDict[cell.peerId.displayName] mutableCopy];
    cell.textLabel.text = cell.peerId.displayName;

    
    // Push
    _chatController.isNavigationControllerVersion = YES;
    [self.navigationController pushViewController:_chatController animated:YES];
}

- (void) chatController:(ChatController *)chatController didSendMessage:(id)message
{
    
    ChatInfo *chatInfo = (ChatInfo*)message;
    NSString *chatText = [chatInfo.message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if(chatText.length>0)
    {
        [self.sessionManager sendData:[chatText dataUsingEncoding:NSUTF8StringEncoding] toPeer:(MCPeerID*)self.chatController.peerId];
        
        // Must add message to controller for it to show
        [_chatController addMessageObject:message];
        [self addChatInfo:chatInfo forDisplayName:[(MCPeerID*)self.chatController.peerId displayName]];
    }
    
}

- (void)addChatInfo:(ChatInfo*)newChatInfo forDisplayName:(NSString*)displayName
{
    NSArray *messageArray = self.messagesDict[displayName];
    if(!messageArray)
    {
        messageArray = @[newChatInfo];
        [self.messagesDict setObject:messageArray forKey:displayName];
        
    }
    else
    {
        NSMutableArray *newMessagesArray = [NSMutableArray new];
        [newMessagesArray addObjectsFromArray:messageArray];
        [newMessagesArray addObject:newChatInfo];
        [self.messagesDict setObject:newMessagesArray forKey:displayName];
    }
}

-(MCPeerID*)getPeerIDForDisplayName:(NSString*)displayName
{
    __block MCPeerID *returnPeerId = nil;
    [self.sessionManager.connectedPeers enumerateObjectsUsingBlock:^(id  __nonnull obj, NSUInteger idx, BOOL * __nonnull stop) {
        MCPeerID *peerID = (MCPeerID*)obj;
        if([peerID.displayName isEqualToString:displayName])
        {
            returnPeerId = peerID;
            *stop = YES;
        }
        
    }];
    
    return returnPeerId;
}

- (void)closeChatController:(ChatController *)chatController
{
    chatController.delegate = nil;
}
@end
