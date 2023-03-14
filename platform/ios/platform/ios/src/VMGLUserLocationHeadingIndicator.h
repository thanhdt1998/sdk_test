#import <QuartzCore/QuartzCore.h>
#import "VMGLUserLocationAnnotationView.h"

@protocol MGLUserLocationHeadingIndicator <NSObject>

- (instancetype)initWithUserLocationAnnotationView:(VMGLUserLocationAnnotationView *)userLocationView;
- (void)updateHeadingAccuracy:(CLLocationDirection)accuracy;
- (void)updateTintColor:(CGColorRef)color;

@end
