//
//  XMPPRoomCoreDataStorageObject.m
//  
//
//  Created by Kashif on 12/9/15.
//
//

#import "XMPPRoomCoreDataStorageObject.h"

@interface XMPPRoomCoreDataStorageObject ()

@property(nonatomic,strong) XMPPJID * primitiveRoomJID;
@property(nonatomic,strong) NSString * primitiveRoomJIDStr;

@end


@implementation XMPPRoomCoreDataStorageObject

@dynamic roomJID, primitiveRoomJID;
@dynamic roomJIDStr, primitiveRoomJIDStr;

@dynamic roomName;
@dynamic inviterStr;
@dynamic reason;
@dynamic unreadMessages;
@dynamic roomImage;


#pragma mark Transient roomJID

- (XMPPJID *)roomJID
{
    // Create and cache on demand
    
    [self willAccessValueForKey:@"roomJID"];
    XMPPJID *tmp = self.primitiveRoomJID;
    [self didAccessValueForKey:@"roomJID"];
    
    if (tmp == nil)
    {
        NSString *roomJIDStr = self.roomJIDStr;
        if (roomJIDStr)
        {
            tmp = [XMPPJID jidWithString:roomJIDStr];
            self.primitiveRoomJID = tmp;
        }
    }
    
    return tmp;
}

- (void)setRoomJID:(XMPPJID *)roomJID
{
    [self willChangeValueForKey:@"roomJID"];
    [self willChangeValueForKey:@"roomJIDStr"];
    
    self.primitiveRoomJID = roomJID;
    self.primitiveRoomJIDStr = [roomJID full];
    
    [self didChangeValueForKey:@"roomJID"];
    [self didChangeValueForKey:@"roomJIDStr"];
}

- (void)setRoomJIDStr:(NSString *)roomJIDStr
{
    [self willChangeValueForKey:@"roomJID"];
    [self willChangeValueForKey:@"roomJIDStr"];
    
    self.primitiveRoomJID = [XMPPJID jidWithString:roomJIDStr];
    self.primitiveRoomJIDStr = roomJIDStr;
    
    [self didChangeValueForKey:@"roomJID"];
    [self didChangeValueForKey:@"roomJIDStr"];
}

@end
