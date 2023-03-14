#import <UIKit/UIKit.h>

#import "VMGLCompassButton.h"

@class VMGLMapView;

NS_ASSUME_NONNULL_BEGIN

@interface VMGLCompassButton (Private)

+ (instancetype)compassButtonWithMapView:(VMGLMapView *)mapView;

@property (nonatomic, weak) VMGLMapView *mapView;

- (void)updateCompass;

@end

NS_ASSUME_NONNULL_END
