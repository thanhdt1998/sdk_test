#import <UIKit/UIKit.h>
#import "VMGLUserLocationAnnotationView.h"

extern const CGFloat MGLUserLocationAnnotationDotSize;
extern const CGFloat MGLUserLocationAnnotationHaloSize;

extern const CGFloat MGLUserLocationAnnotationPuckSize;
extern const CGFloat MGLUserLocationAnnotationArrowSize;

// Threshold in radians between heading indicator rotation updates.
extern const CGFloat MGLUserLocationHeadingUpdateThreshold;

@interface VMGLFaux3DUserLocationAnnotationView : VMGLUserLocationAnnotationView

@end
