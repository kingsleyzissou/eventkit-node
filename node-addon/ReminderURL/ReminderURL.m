#import "ReminderURL.h"
#import <objc/message.h>
#import <objc/runtime.h>
#include <string.h>

@interface REMSaveRequest : NSObject
- (instancetype)initWithStore:(id)store;
- (id)updateReminder:(id)reminder;
- (BOOL)saveSynchronouslyWithError:(NSError **)error;
@end

@interface REMReminderAttachmentContextChangeItem : NSObject
- (id)setURLAttachmentWithURL:(NSURL *)url;
@end

static id ReadPrivateObject(id object, NSString *name) {
    if (!object) {
        return nil;
    }

    SEL selector = NSSelectorFromString(name);
    Method method = class_getInstanceMethod(object_getClass(object), selector);
    if (!method || method_getNumberOfArguments(method) != 2) {
        return nil;
    }

    const char *encoding = method_getTypeEncoding(method);
    if (!encoding || encoding[0] != '@') {
        return nil;
    }

    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static BOOL HasSingleArgumentMethod(
    Class cls,
    SEL selector,
    const char *returnType,
    const char *argumentType
) {
    NSMethodSignature *signature = [cls instanceMethodSignatureForSelector:selector];

    return signature
        && signature.numberOfArguments == 3
        && strcmp(signature.methodReturnType, returnType) == 0
        && strcmp([signature getArgumentTypeAtIndex:2], argumentType) == 0;
}

static NSError *URLWriteError(NSString *message) {
  return [NSError errorWithDomain:@"EventkitNode:ReminderURL"
         code:1
         userInfo:@{NSLocalizedDescriptionKey: message}];
}

NSURL *ReminderAttachmentURL(EKReminder *reminder) {
    @try {
        id backingObject = ReadPrivateObject(reminder, @"backingObject");
        id remObject = ReadPrivateObject(backingObject, @"REMObject");
        id context = ReadPrivateObject(remObject, @"attachmentContext");
        id attachments = ReadPrivateObject(context, @"urlAttachments");

        if (![attachments isKindOfClass:[NSArray class]]) {
            return nil;
        }

        id attachment = [( NSArray *)attachments firstObject];
        id url = ReadPrivateObject(attachment, @"url");

        if (![url isKindOfClass:[NSURL class]]) {
            return nil;
        }

        return url;
    } @catch(NSException *exception) {
        NSLog(@"Reminder URL read failed: %@", exception);
        return nil;
    }
}

NSError *SetReminderAttachmentURL(EKReminder *reminder, NSURL *url) {
    @try {
        if (!url || ![url isKindOfClass:[NSURL class]]) {
            return URLWriteError(@"A reminder and URL are required");
        }

        id backingObject = ReadPrivateObject(reminder, @"backingObject");
        id remObject = ReadPrivateObject(backingObject, @"REMObject");
        id store = ReadPrivateObject(remObject, @"store");

        if (!remObject || !store) {
            return URLWriteError(@"Could not access underlying reminder or store");
        }

        Class requestClass = NSClassFromString(@"REMSaveRequest");
        if (
            !requestClass
            || !HasSingleArgumentMethod(requestClass, @selector(initWithStore:), "@", "@")
            || !HasSingleArgumentMethod(requestClass, @selector(updateReminder:), "@", "@")
            || !HasSingleArgumentMethod(requestClass, @selector(saveSynchronouslyWithError:), @encode(BOOL), "^@")
        ) {
            return URLWriteError(@"The private save API is unavailable or incompatible");
        }

        REMSaveRequest *request = [[requestClass alloc] initWithStore:store];
        if (!request) {
            return URLWriteError(@"Could not create a reminder save request");
        }

        id changeItem = [request updateReminder:remObject];
        REMReminderAttachmentContextChangeItem *context = ReadPrivateObject(changeItem, @"attachmentContext");
        if (
            !context
            || !HasSingleArgumentMethod(object_getClass(context), @selector(setURLAttachmentWithURL:), "@", "@")
        ) {
            return URLWriteError(@"The URL attachment editor is unavailable or incompatible");
        }

        [context setURLAttachmentWithURL:url];

        NSError *error = nil;
        if (![request saveSynchronouslyWithError:&error]) {
            return error ?: URLWriteError(@"Saving the URL attachment failed");
        }

        return nil;
    } @catch (NSException *exception) {
        return URLWriteError(exception.reason ?: @"The private URL write API threw an exception");
    }
}
