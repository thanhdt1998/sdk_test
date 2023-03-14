#import <QuartzCore/QuartzCore.h>
#import "VMGLUserLocationAnnotationView.h"
#import "VMGLUserLocationHeadingIndicator.h"

@interface MGLUserLocationHeadingArrowLayer : CAShapeLayer <MGLUserLocationHeadingIndicator>

- (instancetype)initWithUserLocationAnnotationView:(VMGLUserLocationAnnotationView *)userLocationView;
- (void)updateHeadingAccuracy:(CLLocationDirection)accuracy;
- (void)updateTintColor:(CGColorRef)color;

@end
