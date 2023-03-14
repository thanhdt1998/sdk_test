@import Mapbox;

#import "VMAppDelegate.h"
#import "VMViewController.h"

@interface VMAppDelegate()

@end

@implementation VMAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
#ifndef MGL_DISABLE_LOGGING
    [MGLLoggingConfiguration sharedConfiguration].loggingLevel = MGLLoggingLevelFault;
#endif
    [VMGLSettings useWellKnownTileServer:MGLMapTiler];

    return YES;
}

#pragma mark - Quick actions

- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler {
    completionHandler([self handleShortcut:shortcutItem]);
}

- (BOOL)handleShortcut:(UIApplicationShortcutItem *)shortcut {
    if ([[shortcut.type componentsSeparatedByString:@"."].lastObject isEqual:@"settings"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:^(BOOL success) {
                if (success) {
                     NSLog(@"Opened url");
                }
            }];
        });

        return YES;
    }

    return NO;
}

@end
