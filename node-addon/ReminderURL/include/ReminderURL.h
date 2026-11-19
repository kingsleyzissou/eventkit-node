#import <Foundation/Foundation.h>
#import <EventKit/EventKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSURL * _Nullable ReminderAttachmentURL(EKReminder *reminder);

FOUNDATION_EXPORT NSError * _Nullable SetReminderAttachmentURL(
    EKReminder *reminder,
    NSURL *url
);

NS_ASSUME_NONNULL_END
