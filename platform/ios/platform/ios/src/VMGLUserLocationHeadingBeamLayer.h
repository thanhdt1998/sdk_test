#import <QuartzCore/QuartzCore.h>
#import "VMGLUserLocationAnnotationView.h"
#import "VMGLUserLocationHeadingIndicator.h"

@interface MGLUserLocationHeadingBeamLayer : CALayer <MGLUserLocationHeadingIndicator>

- (MGLUserLocationHeadingBeamLayer *)initWithUserLocationAnnotationView:(VMGLUserLocationAnnotationView *)userLocationView;
- (void)updateHeadingAccuracy:(CLLocationDirection)accuracy;
- (void)updateTintColor:(CGColorRef)color;

@end
