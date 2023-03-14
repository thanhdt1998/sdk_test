#import <Foundation/Foundation.h>
#import "VMViewController.h"
@class VMState;

NS_ASSUME_NONNULL_BEGIN

@interface VMStateManager : NSObject

+ (instancetype) sharedManager;

- (VMState *)currentState;

- (void)saveState:(VMState*)mapViewController;

- (void)resetState;

@end

NS_ASSUME_NONNULL_END
