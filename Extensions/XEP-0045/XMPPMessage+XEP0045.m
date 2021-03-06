#import "XMPPMessage+XEP0045.h"
#import "NSXMLElement+XMPP.h"


@implementation XMPPMessage(XEP0045)

- (BOOL)isGroupChatMessage
{
    return [[[self attributeForName:@"type"] stringValue] isEqualToString:@"groupchat"];
}

- (BOOL)isGroupChatMessageWithBody
{
    if ([self isGroupChatMessage])
    {
        NSString *body = [[self elementForName:@"body"] stringValue];
        
        return ([body length] > 0);
    }
    
    return NO;
}

- (BOOL)isGroupChatMessageWithSubject
{
    if ([self isGroupChatMessage])
    {
        NSString *subject = [[self elementForName:@"subject"] stringValue];
        
        return ([subject length] > 0);
    }
    
    return NO;
}

- (BOOL)isGroupChatMessageWithAdmin
{
    DDXMLElement *elementAdmin = [self elementForName:@"admin"];
    if (elementAdmin != nil) {
        return YES;
    }
    return NO;
}

- (NSString *)getAdminJID
{
    DDXMLElement *elementAdmin = [self elementForName:@"admin"];
    if (elementAdmin != nil) {
        NSString *jid = [[elementAdmin elementForName:@"jid"] stringValue];
        if ([jid length] > 0) {
            return jid;
        }
    }
    return nil;
}

- (BOOL)isGroupChatMessageWithMetadata
{
    DDXMLElement *elementAdmin = [self elementForName:@"metadata"];
    if (elementAdmin != nil) {
        return YES;
    }
    return NO;
}

- (BOOL)isGroupChatMessageWithNewUser
{
    DDXMLElement *element = [self elementForName:@"add"];
    if (element != nil) {
        return YES;
    }
    return NO;
}

- (BOOL)isGroupChatMessageWithRemoveUser
{
    DDXMLElement *element = [self elementForName:@"kicked"];
    if (element != nil) {
        return YES;
    }
    return NO;
}

- (BOOL)isGroupChatMessageWithExit
{
    DDXMLElement *element = [self elementForName:@"exit"];
    if (element != nil) {
        return YES;
    }
    return NO;
}

@end
