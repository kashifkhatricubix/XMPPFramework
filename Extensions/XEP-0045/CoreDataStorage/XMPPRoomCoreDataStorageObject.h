//
//  XMPPRoomCoreDataStorageObject.h
//  
//
//  Created by Kashif on 12/9/15.
//
//

#import "XMPP.h"
#import "XMPPRoom.h"

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface XMPPRoomCoreDataStorageObject : NSManagedObject

@property (nonatomic, retain) XMPPJID * roomJID;
@property (nonatomic, retain) NSString * roomName;
@property (nonatomic, retain) NSString * roomImage;
@property (nonatomic, retain) NSString * roomJIDStr;
@property (nonatomic, retain) NSString * inviterStr;
@property (nonatomic, retain) NSString * reason;
@property (nonatomic, retain) NSNumber * unreadMessages;

@end
