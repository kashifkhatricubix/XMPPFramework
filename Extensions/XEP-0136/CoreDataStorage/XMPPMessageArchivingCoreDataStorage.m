#import "XMPPMessageArchivingCoreDataStorage.h"
#import "XMPPCoreDataStorageProtected.h"
#import "XMPPLogging.h"
#import "NSXMLElement+XEP_0203.h"
#import "XMPPMessage+XEP_0085.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN; // VERBOSE; // | XMPP_LOG_FLAG_TRACE;
#else
static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@interface XMPPMessageArchivingCoreDataStorage ()
{
    NSString *messageEntityName;
    NSString *contactEntityName;
    NSArray<NSString *> *relevantContentXPaths;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPMessageArchivingCoreDataStorage

static XMPPMessageArchivingCoreDataStorage *sharedInstance;

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        sharedInstance = [[XMPPMessageArchivingCoreDataStorage alloc] initWithDatabaseFilename:nil storeOptions:nil];
    });
    
    return sharedInstance;
}

/**
 * Documentation from the superclass (XMPPCoreDataStorage):
 *
 * If your subclass needs to do anything for init, it can do so easily by overriding this method.
 * All public init methods will invoke this method at the end of their implementation.
 *
 * Important: If overriden you must invoke [super commonInit] at some point.
 **/
- (void)commonInit
{
    [super commonInit];
    
    messageEntityName = @"XMPPMessageArchiving_Message_CoreDataObject";
    contactEntityName = @"XMPPMessageArchiving_Contact_CoreDataObject";
    
    relevantContentXPaths = @[@"./*[local-name()='body']"];
}

/**
 * Documentation from the superclass (XMPPCoreDataStorage):
 *
 * Override me, if needed, to provide customized behavior.
 * For example, you may want to perform cleanup of any non-persistent data before you start using the database.
 *
 * The default implementation does nothing.
 **/
- (void)didCreateManagedObjectContext
{
    // If there are any "composing" messages in the database, delete them (as they are temporary).
    
    NSManagedObjectContext *moc = [self managedObjectContext];
    NSEntityDescription *messageEntity = [self messageEntity:moc];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"composing == YES"];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = messageEntity;
    fetchRequest.predicate = predicate;
    fetchRequest.fetchBatchSize = saveThreshold;
    
    NSError *error = nil;
    NSArray *messages = [moc executeFetchRequest:fetchRequest error:&error];
    
    if (messages == nil)
    {
        XMPPLogError(@"%@: %@ - Error executing fetchRequest: %@", [self class], THIS_METHOD, error);
        return;
    }
    
    NSUInteger count = 0;
    
    for (XMPPMessageArchiving_Message_CoreDataObject *message in messages)
    {
        [moc deleteObject:message];
        
        if (++count > saveThreshold)
        {
            if (![moc save:&error])
            {
                XMPPLogWarn(@"%@: Error saving - %@ %@", [self class], error, [error userInfo]);
                [moc rollback];
            }
        }
    }
    
    if (count > 0)
    {
        if (![moc save:&error])
        {
            XMPPLogWarn(@"%@: Error saving - %@ %@", [self class], error, [error userInfo]);
            [moc rollback];
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Internal API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)willInsertMessage:(XMPPMessageArchiving_Message_CoreDataObject *)message
{
    // Override hook
}

- (void)didUpdateMessage:(XMPPMessageArchiving_Message_CoreDataObject *)message
{
    // Override hook
}

- (void)willDeleteMessage:(XMPPMessageArchiving_Message_CoreDataObject *)message
{
    // Override hook
}

- (void)willInsertContact:(XMPPMessageArchiving_Contact_CoreDataObject *)contact
{
    // Override hook
}

- (void)didUpdateContact:(XMPPMessageArchiving_Contact_CoreDataObject *)contact
{
    // Override hook
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPMessageArchiving_Message_CoreDataObject *)composingMessageWithJid:(XMPPJID *)messageJid
                                                               streamJid:(XMPPJID *)streamJid
                                                                outgoing:(BOOL)isOutgoing
                                                    managedObjectContext:(NSManagedObjectContext *)moc
{
    XMPPMessageArchiving_Message_CoreDataObject *result = nil;
    
    NSEntityDescription *messageEntity = [self messageEntity:moc];
    
    // Order matters:
    // 1. composing - most likely not many with it set to YES in database
    // 2. bareJidStr - splits database by number of conversations
    // 3. outgoing - splits database in half
    // 4. streamBareJidStr - might not limit database at all
    
    NSString *predicateFrmt = @"composing == YES AND bareJidStr == %@ AND outgoing == %@ AND streamBareJidStr == %@";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFrmt,
                              [messageJid bare], @(isOutgoing),
                              [streamJid bare]];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = messageEntity;
    fetchRequest.predicate = predicate;
    fetchRequest.sortDescriptors = @[sortDescriptor];
    fetchRequest.fetchLimit = 1;
    
    NSError *error = nil;
    NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];
    
    if (results == nil || error)
    {
        XMPPLogError(@"%@: %@ - Error executing fetchRequest: %@", THIS_FILE, THIS_METHOD, fetchRequest);
    }
    else
    {
        result = (XMPPMessageArchiving_Message_CoreDataObject *)[results lastObject];
    }
    
    return result;
}

- (XMPPMessageArchiving_Message_CoreDataObject *)composingMessageWithJid:(XMPPJID *)messageJid
                                                               streamJid:(XMPPJID *)streamJid
                                                                outgoing:(BOOL)isOutgoing
                                                               messageID:(NSString *)messageId
                                                    managedObjectContext:(NSManagedObjectContext *)moc
{
    XMPPMessageArchiving_Message_CoreDataObject *result = nil;
    
    NSEntityDescription *messageEntity = [self messageEntity:moc];
    
    // Order matters:
    // 1. composing - most likely not many with it set to YES in database
    // 2. bareJidStr - splits database by number of conversations
    // 3. outgoing - splits database in half
    // 4. streamBareJidStr - might not limit database at all
    
    //    NSString *predicateFrmt = @"composing == YES AND bareJidStr == %@ AND outgoing == %@ AND streamBareJidStr == %@";
    //    NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFrmt, [messageJid bare], @(isOutgoing), [streamJid bare]];
    
    NSString *predicateFrmt = @"messageID == %@";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFrmt, messageId];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = messageEntity;
    fetchRequest.predicate = predicate;
    fetchRequest.sortDescriptors = @[sortDescriptor];
    fetchRequest.fetchLimit = 1;
    
    NSError *error = nil;
    NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];
    
    if (results == nil || error)
    {
        XMPPLogError(@"%@: %@ - Error executing fetchRequest: %@", THIS_FILE, THIS_METHOD, fetchRequest);
    }
    else
    {
        result = (XMPPMessageArchiving_Message_CoreDataObject *)[results lastObject];
    }
    
    return result;
}

- (BOOL)messageContainsRelevantContent:(XMPPMessage *)message
{
    for (NSString *XPath in self.relevantContentXPaths) {
        NSError *error;
        NSArray *nodes = [message nodesForXPath:XPath error:&error];
        if (!nodes) {
            XMPPLogError(@"%@: %@ - Error querying XPath (%@): %@", THIS_FILE, THIS_METHOD, XPath, error);
            continue;
        }
        
        for (NSXMLNode *node in nodes) {
            if (node.stringValue.length > 0) {
                return YES;
            }
        }
    }
    
    return NO;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPMessageArchiving_Contact_CoreDataObject *)contactForMessage:(XMPPMessageArchiving_Message_CoreDataObject *)msg
{
    // Potential override hook
    
    return [self contactWithBareJidStr:msg.bareJidStr
                      streamBareJidStr:msg.streamBareJidStr
                  managedObjectContext:msg.managedObjectContext];
}

- (XMPPMessageArchiving_Contact_CoreDataObject *)contactWithJid:(XMPPJID *)contactJid
                                                      streamJid:(XMPPJID *)streamJid
                                           managedObjectContext:(NSManagedObjectContext *)moc
{
    return [self contactWithBareJidStr:[contactJid bare]
                      streamBareJidStr:[streamJid bare]
                  managedObjectContext:moc];
}

- (XMPPMessageArchiving_Contact_CoreDataObject *)contactWithBareJidStr:(NSString *)contactBareJidStr
                                                      streamBareJidStr:(NSString *)streamBareJidStr
                                                  managedObjectContext:(NSManagedObjectContext *)moc
{
    NSEntityDescription *entity = [self contactEntity:moc];
    
    NSPredicate *predicate;
    //	if (streamBareJidStr)
    //	{
    //		predicate = [NSPredicate predicateWithFormat:@"bareJidStr == %@ AND streamBareJidStr == %@",
    //	                                                              contactBareJidStr, streamBareJidStr];
    //	}
    //	else
    //	{
    predicate = [NSPredicate predicateWithFormat:@"bareJidStr == %@", contactBareJidStr];
    //	}
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:entity];
    [fetchRequest setFetchLimit:1];
    [fetchRequest setPredicate:predicate];
    
    NSError *error = nil;
    NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];
    
    if (results == nil)
    {
        XMPPLogError(@"%@: %@ - Fetch request error: %@", THIS_FILE, THIS_METHOD, error);
        return nil;
    }
    else
    {
        return (XMPPMessageArchiving_Contact_CoreDataObject *)[results lastObject];
    }
}

- (NSString *)messageEntityName
{
    __block NSString *result = nil;
    
    dispatch_block_t block = ^{
        result = messageEntityName;
    };
    
    if (dispatch_get_specific(storageQueueTag))
        block();
    else
        dispatch_sync(storageQueue, block);
    
    return result;
}

- (void)setMessageEntityName:(NSString *)entityName
{
    dispatch_block_t block = ^{
        messageEntityName = entityName;
    };
    
    if (dispatch_get_specific(storageQueueTag))
        block();
    else
        dispatch_async(storageQueue, block);
}

- (NSString *)contactEntityName
{
    __block NSString *result = nil;
    
    dispatch_block_t block = ^{
        result = contactEntityName;
    };
    
    if (dispatch_get_specific(storageQueueTag))
        block();
    else
        dispatch_sync(storageQueue, block);
    
    return result;
}

- (void)setContactEntityName:(NSString *)entityName
{
    dispatch_block_t block = ^{
        contactEntityName = entityName;
    };
    
    if (dispatch_get_specific(storageQueueTag))
        block();
    else
        dispatch_async(storageQueue, block);
}

- (NSEntityDescription *)messageEntity:(NSManagedObjectContext *)moc
{
    // This is a public method, and may be invoked on any queue.
    // So be sure to go through the public accessor for the entity name.
    
    return [NSEntityDescription entityForName:[self messageEntityName] inManagedObjectContext:moc];
}

- (NSEntityDescription *)contactEntity:(NSManagedObjectContext *)moc
{
    // This is a public method, and may be invoked on any queue.
    // So be sure to go through the public accessor for the entity name.
    
    return [NSEntityDescription entityForName:[self contactEntityName] inManagedObjectContext:moc];
}

- (NSArray<NSString *> *)relevantContentXPaths
{
    __block NSArray *result;
    
    dispatch_block_t block = ^{
        result = relevantContentXPaths;
    };
    
    if (dispatch_get_specific(storageQueueTag))
        block();
    else
        dispatch_sync(storageQueue, block);
    
    return result;
}

- (void)setRelevantContentXPaths:(NSArray<NSString *> *)relevantContentXPathsToSet
{
    NSArray *newValue = [relevantContentXPathsToSet copy];
    
    dispatch_block_t block = ^{
        relevantContentXPaths = newValue;
    };
    
    if (dispatch_get_specific(storageQueueTag))
        block();
    else
        dispatch_async(storageQueue, block);
}

- (void) setMessageFailed:(NSString *)messageId
{
    XMPPMessageArchivingCoreDataStorage *storage = [XMPPMessageArchivingCoreDataStorage sharedInstance];
    NSManagedObjectContext *moc = [storage mainThreadManagedObjectContext];
    NSEntityDescription *entityDescription = [self messageEntity:moc];
    
    NSFetchRequest *request = [[NSFetchRequest alloc]init];
    
    NSPredicate *p=[NSPredicate predicateWithFormat:@"messageID == %@", messageId];
    [request setPredicate:p];
    [request setEntity:entityDescription];
    
    NSError *error;
    NSArray *messages = [moc executeFetchRequest:request error:&error];
    
    if ([messages count] > 0) {
        XMPPMessageArchiving_Message_CoreDataObject *message = [messages lastObject];
        
        [message setIsFailed:YES];
        
        if (![moc save:&error])
        {
            XMPPLogWarn(@"%@: Error saving - %@ %@", [self class], error, [error userInfo]);
            [moc rollback];
        }
    }
}

- (void) insertContact:(XMPPMessage *)message
{
    [self scheduleBlock:^{
        
        NSDate *stamp;
        
        NSManagedObjectContext *moc = [self managedObjectContext];
        //    XMPPMessageArchiving_Contact_CoreDataObject *contact = [self contactWithBareJidStr:[[message from] bare] streamBareJidStr:[[message from] bare] managedObjectContext:moc];
        
        //    if (contact == nil) {
        XMPPMessageArchiving_Contact_CoreDataObject *contact = (XMPPMessageArchiving_Contact_CoreDataObject *)
        [[NSManagedObject alloc] initWithEntity:[self contactEntity:moc]
                 insertIntoManagedObjectContext:nil];
        //    }
        
        contact.streamBareJidStr = [[message to] bare];
        contact.bareJid = message.from;
        contact.mostRecentMessageBody = [message body];
        contact.mostRecentMessageOutgoing = [NSNumber numberWithBool:false];
        
        if ([message attributeForName:@"timestamp"] != nil) {
            NSString *stampValue = [message attributeStringValueForName:@"timestamp"];
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
            [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
            [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
            
            stamp = [dateFormatter dateFromString:stampValue];
            contact.mostRecentMessageTimestamp = stamp;
        } else {
            contact.mostRecentMessageTimestamp = [NSDate date];
        }
        
        contact.unreadMessages = [NSNumber numberWithInteger:0];
        [moc insertObject:contact];
        NSError *error;
        
        if (![moc save:&error])
        {
            XMPPLogWarn(@"%@: Error saving - %@ %@", [self class], error, [error userInfo]);
            [moc rollback];
        }
    }];
}

- (void) updateContact:(XMPPMessage *)message JID:(XMPPJID *)jid counter:(NSInteger)number
{
    [self scheduleBlock:^{
        
        NSManagedObjectContext *moc = [self managedObjectContext];
        XMPPMessageArchiving_Contact_CoreDataObject *contact = [self contactWithJid:jid streamJid:jid managedObjectContext:moc];
        
        contact.streamBareJidStr = [[message to] bare];
        contact.bareJid = message.from;
        contact.mostRecentMessageBody = [message body];
        contact.mostRecentMessageOutgoing = [NSNumber numberWithBool:false];
        contact.mostRecentMessageTimestamp = [NSDate date];
        
        if (number != 0) {
            contact.unreadMessages = [NSNumber numberWithInteger:(contact.unreadMessages.integerValue + number)];
        }
        
        NSError *error;
        
        if (![moc save:&error])
        {
            XMPPLogWarn(@"%@: Error saving - %@ %@", [self class], error, [error userInfo]);
            [moc rollback];
        }
    }];
}

- (void) clearContactData:(XMPPJID *)jid
{
    [self scheduleBlock:^{
        
        NSManagedObjectContext *moc = [self managedObjectContext];
        XMPPMessageArchiving_Contact_CoreDataObject *contact = [self contactWithJid:jid streamJid:jid managedObjectContext:moc];
        
        [contact setUnreadMessages:[NSNumber numberWithInteger:0]];
        contact.mostRecentMessageBody = @"";
        
        NSError *error;
        
        if (![moc save:&error])
        {
            XMPPLogWarn(@"%@: Error saving - %@ %@", [self class], error, [error userInfo]);
            [moc rollback];
        }
    }];
}

- (void) updateContactNickName:(NSString *)nickName JID:(XMPPJID *)jid
{
    [self scheduleBlock:^{
        
        NSManagedObjectContext *moc = [self managedObjectContext];
        XMPPMessageArchiving_Contact_CoreDataObject *contact = [self contactWithJid:jid streamJid:jid managedObjectContext:moc];
        
        contact.nickName = nickName;
        
        NSError *error;
        
        if (![moc save:&error])
        {
            XMPPLogWarn(@"%@: Error saving - %@ %@", [self class], error, [error userInfo]);
            [moc rollback];
        }
    }];
}

- (void) deleteContact:(XMPPJID *)jid
{
    [self scheduleBlock:^{
        
        NSManagedObjectContext *moc = [self managedObjectContext];
        XMPPMessageArchiving_Contact_CoreDataObject *contact = [self contactWithJid:jid streamJid:jid managedObjectContext:moc];
        
        if (contact != nil) {
            [moc deleteObject:contact];
            NSError *error;
            
            if (![moc save:&error])
            {
                XMPPLogWarn(@"%@: Error saving - %@ %@", [self class], error, [error userInfo]);
                [moc rollback];
            }
        }
    }];
}

- (void) deleteAllContacts
{
    [self scheduleBlock:^{
        
        NSManagedObjectContext *moc = [self managedObjectContext];
        NSEntityDescription *entity = [self contactEntity:moc];
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];
        
        for (XMPPMessageArchiving_Contact_CoreDataObject *contact in results) {
            [moc deleteObject:contact];
            
        }
        
        if (![moc save:&error])
        {
            XMPPLogWarn(@"%@: Error saving - %@ %@", [self class], error, [error userInfo]);
            [moc rollback];
        }
    }];
}

- (void) deleteAllMessages
{
    [self scheduleBlock:^{
        
        NSManagedObjectContext *moc = [self managedObjectContext];
        NSEntityDescription *entity = [self messageEntity:moc];
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequest:fetchRequest error:&error];
        
        for (XMPPMessageArchiving_Message_CoreDataObject *message in results) {
            [moc deleteObject:message];
        }
        
        if (![moc save:&error])
        {
            XMPPLogWarn(@"%@: Error saving - %@ %@", [self class], error, [error userInfo]);
            [moc rollback];
        }
    }];
}

- (void) resetCount:(XMPPJID *)jid
{
    [self scheduleBlock:^{
        NSManagedObjectContext *moc = [self managedObjectContext];
        
        NSEntityDescription *entityDescription = [self contactEntity:moc];
        
        NSFetchRequest *request = [[NSFetchRequest alloc]init];
        
        NSPredicate *p=[NSPredicate predicateWithFormat:@"bareJidStr == %@", [jid bare]];
        [request setPredicate:p];
        [request setEntity:entityDescription];
        
        NSError *error;
        NSArray *contacts = [moc executeFetchRequest:request error:&error];
        
        if ([contacts count] > 0) {
            XMPPMessageArchiving_Contact_CoreDataObject *contact = [contacts lastObject];
            
            [contact setUnreadMessages:[NSNumber numberWithInteger:0]];
            // setIsFailed:YES];
            
            if (![moc save:&error])
            {
                XMPPLogWarn(@"%@: Error saving - %@ %@", [self class], error, [error userInfo]);
                [moc rollback];
            }
        }
    }];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Storage Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)configureWithParent:(XMPPMessageArchiving *)aParent queue:(dispatch_queue_t)queue
{
    return [super configureWithParent:aParent queue:queue];
}

- (void)archiveMessage:(XMPPMessage *)message outgoing:(BOOL)isOutgoing xmppStream:(XMPPStream *)xmppStream
{
    // Message should either have a body, or be a composing notification
    
    NSString *messageBody = [[message elementForName:@"body"] stringValue];
    BOOL isComposing = NO;
    BOOL shouldDeleteComposingMessage = NO;
    
    if (![self messageContainsRelevantContent:message])
    {
        // Message doesn't have any content relevant for the module's user.
        // Check to see if it has a chat state (composing, paused, etc).
        
        isComposing = [message hasComposingChatState];
        if (!isComposing)
        {
            if ([message hasChatState])
            {
                // Message has non-composing chat state.
                // So if there is a current composing message in the database,
                // then we need to delete it.
                shouldDeleteComposingMessage = YES;
            }
            else
            {
                // Message has no body and no chat state.
                // Nothing to do with it.
                return;
            }
        }
    }
    
    [self scheduleBlock:^{
        
        NSManagedObjectContext *moc = [self managedObjectContext];
        XMPPJID *myJid = [self myJIDForXMPPStream:xmppStream];
        
        XMPPJID *messageJid = isOutgoing ? [message to] : [message from];
        NSString *messageID = [message attributeStringValueForName:@"id"];
        // Fetch-n-Update OR Insert new message
        
        XMPPMessageArchiving_Message_CoreDataObject *archivedMessage =
        [self composingMessageWithJid:messageJid
                            streamJid:myJid
                             outgoing:isOutgoing
                            messageID:messageID
                 managedObjectContext:moc];
        
        if (shouldDeleteComposingMessage)
        {
            if (archivedMessage)
            {
                [self willDeleteMessage:archivedMessage]; // Override hook
                [moc deleteObject:archivedMessage];
            }
            else
            {
                // Composing message has already been deleted (or never existed)
            }
        }
        else
        {
            XMPPLogVerbose(@"Previous archivedMessage: %@", archivedMessage);
            
            BOOL didCreateNewArchivedMessage = NO;
            if (archivedMessage == nil)
            {
                archivedMessage = (XMPPMessageArchiving_Message_CoreDataObject *)
                [[NSManagedObject alloc] initWithEntity:[self messageEntity:moc]
                         insertIntoManagedObjectContext:nil];
                
                if (!isOutgoing) {
                    NSNumber  *aNum = [NSNumber numberWithInteger:[messageID integerValue]];
                    [archivedMessage setMessageID:aNum];
                }
                
                didCreateNewArchivedMessage = YES;
                
                [archivedMessage setIsFailed:NO];
                
                NSLog(@"%@",messageBody);
                
                archivedMessage.type = [NSNumber numberWithInteger:0];
                
                archivedMessage.message = message;
                archivedMessage.body = messageBody;
                
                archivedMessage.bareJid = [messageJid bareJID];
                archivedMessage.streamBareJidStr = [myJid bare];
                
            } else {
                
                archivedMessage.message = message;
                archivedMessage.body = messageBody;
                
                archivedMessage.bareJid = [messageJid bareJID];
                archivedMessage.streamBareJidStr = [myJid bare];
                archivedMessage.isFailed    = archivedMessage.isFailed;
                archivedMessage.type    = archivedMessage.type;
            }
            
            NSDate *timestamp = [message delayedDeliveryDate];
            if (timestamp)
            {
                archivedMessage.timestamp = timestamp;
            }
            else
            {
                if (archivedMessage.timestamp == nil) {
                    archivedMessage.timestamp = [[NSDate alloc] init];
                } else {
                    archivedMessage.timestamp = archivedMessage.timestamp;
                }
            }
            
            archivedMessage.thread = [[message elementForName:@"thread"] stringValue];
            archivedMessage.isOutgoing = isOutgoing;
            
            archivedMessage.isComposing = isComposing;
            
            XMPPLogVerbose(@"New archivedMessage: %@", archivedMessage);
            
            if (didCreateNewArchivedMessage) // [archivedMessage isInserted] doesn't seem to work
            {
                XMPPLogVerbose(@"Inserting message...");
                
                [archivedMessage
                 willInsertObject];       // Override hook
                [self willInsertMessage:archivedMessage]; // Override hook
                [moc insertObject:archivedMessage];
            }
            else
            {
                XMPPLogVerbose(@"Updating message...");
                
                [archivedMessage didUpdateObject];       // Override hook
                [self didUpdateMessage:archivedMessage]; // Override hook
            }
            
            // Create or update contact (if message with actual content)
            
            if ([messageBody length] > 0)
            {
                BOOL didCreateNewContact = NO;
                
                XMPPMessageArchiving_Contact_CoreDataObject *contact = [self contactForMessage:archivedMessage];
                XMPPLogVerbose(@"Previous contact: %@", contact);
                
                if (contact == nil)
                {
                    contact = (XMPPMessageArchiving_Contact_CoreDataObject *)
                    [[NSManagedObject alloc] initWithEntity:[self contactEntity:moc]
                             insertIntoManagedObjectContext:nil];
                    
                    didCreateNewContact = YES;
                }
                
                contact.streamBareJidStr = archivedMessage.streamBareJidStr;
                contact.bareJid = archivedMessage.bareJid;
                
                contact.mostRecentMessageTimestamp = archivedMessage.timestamp;
                contact.mostRecentMessageBody = archivedMessage.body;
                contact.mostRecentMessageOutgoing = [NSNumber numberWithBool:isOutgoing];
                if (isOutgoing == false && didCreateNewArchivedMessage == YES) {
                    contact.nickName = [message attributeStringValueForName:@"number"];
                    contact.unreadMessages = [NSNumber numberWithInteger:(contact.unreadMessages.integerValue) + 1];
                }
                
                XMPPLogVerbose(@"New contact: %@", contact);
                
                if (didCreateNewContact) // [contact isInserted] doesn't seem to work
                {
                    XMPPLogVerbose(@"Inserting contact...");
                    
                    [contact willInsertObject];       // Override hook
                    [self willInsertContact:contact]; // Override hook
                    [moc insertObject:contact];
                }
                else
                {
                    XMPPLogVerbose(@"Updating contact...");
                    
                    [contact didUpdateObject];       // Override hook
                    [self didUpdateContact:contact]; // Override hook
                }
            }
        }
    }];
}

@end
