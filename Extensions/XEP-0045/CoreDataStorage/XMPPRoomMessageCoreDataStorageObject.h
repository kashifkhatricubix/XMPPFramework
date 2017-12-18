#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "XMPP.h"
#import "XMPPRoom.h"


@interface XMPPRoomMessageCoreDataStorageObject : NSManagedObject <XMPPRoomMessage>

/**
 * The properties below are documented in the XMPPRoomMessage protocol.
**/

@property (nonatomic, strong) NSString *messageID;

@property (nonatomic, retain) XMPPMessage * message;  // Transient (proper type, not on disk)
@property (nonatomic, retain) NSString * messageStr;  // Shadow (binary data, written to disk)

@property (nonatomic, strong) XMPPJID * roomJID;      // Transient (proper type, not on disk)
@property (nonatomic, strong) NSString * roomJIDStr;  // Shadow (binary data, written to disk)

@property (nonatomic, retain) XMPPJID * jid;          // Transient (proper type, not on disk)
@property (nonatomic, retain) NSString * jidStr;      // Shadow (binary data, written to disk)

@property (nonatomic, retain) NSString * nickname;
@property (nonatomic, retain) NSString * body;

@property (nonatomic, retain) NSDate * localTimestamp;
@property (nonatomic, strong) NSDate * remoteTimestamp;

@property (nonatomic, assign) BOOL isFromMe;
@property (nonatomic, strong) NSNumber * fromMe;

@property (nonatomic, strong) NSNumber * failed;   // Use isFailed
@property (nonatomic, assign) BOOL isFailed;       // Convenience property

@property (nonatomic, strong) NSNumber * newMessage;
@property (nonatomic, assign) BOOL isNewMessage;

/**
 * The 'type' property can be used to inject message type.
 * For example: "0 for text message, 1 for image, 2 for video".
 */
@property (nonatomic, strong) NSNumber * messageType;

/**
 * The 'type' property can be used to inject event messages.
 * For example: "JohnDoe entered the room".
 * 
 * You can define your own types to suit your needs.
 * All normal messages will have a type of zero.
**/
@property (nonatomic, strong) NSNumber * type;

/**
 * If a single instance of XMPPRoomCoreDataStorage is shared between multiple xmppStream's,
 * this may be needed to distinguish between the streams.
**/
@property (nonatomic, strong) NSString *streamBareJidStr;

@end
