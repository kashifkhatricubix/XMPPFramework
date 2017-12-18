#import <Foundation/Foundation.h>
#import "XMPPMessage.h"


@interface XMPPMessage(XEP0045)

@property (nonatomic, readonly) BOOL isGroupChatMessage;
@property (nonatomic, readonly) BOOL isGroupChatMessageWithBody;
@property (nonatomic, readonly) BOOL isGroupChatMessageWithSubject;
@property (nonatomic, readonly) BOOL isGroupChatMessageWithAdmin;
@property (nonatomic, readonly) BOOL isGroupChatMessageWithMetadata;
@property (nonatomic, readonly) BOOL isGroupChatMessageWithNewUser;
@property (nonatomic, readonly) BOOL isGroupChatMessageWithRemoveUser;
@property (nonatomic, readonly) NSString* getAdminJID;
@end
