#import "ReminderURL.h"
#import <objc/message.h>
#import <objc/runtime.h>

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
