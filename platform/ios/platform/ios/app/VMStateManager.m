#import "VMStateManager.h"
#import "VMState.h"
#import "VMViewController.h"

static NSString * const MBXStateManagerMapStateKey = @"mapStateKey";

@interface VMStateManager()

@property (strong, nonatomic) VMState *currentState;

@end

@implementation VMStateManager

+ (instancetype) sharedManager {
    static dispatch_once_t once;
    static VMStateManager* sharedManager;
    dispatch_once(&once, ^{
        sharedManager = [[self alloc] init];
    });

    return sharedManager;
}

- (VMState*)currentState {
    NSData *encodedMapState = [[NSUserDefaults standardUserDefaults] objectForKey:MBXStateManagerMapStateKey];
    VMState *currentState = (VMState *)[NSKeyedUnarchiver unarchiveObjectWithData:encodedMapState];

    return currentState;
}

- (void)saveState:(VMState*)mapState {
    NSData *encodedMapState = [NSKeyedArchiver archivedDataWithRootObject:mapState];
    [[NSUserDefaults standardUserDefaults] setObject:encodedMapState forKey:MBXStateManagerMapStateKey];
}

- (void)resetState {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:MBXStateManagerMapStateKey];
}



@end
