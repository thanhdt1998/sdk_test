#import "VMGLMultiPoint.h"

#import "VMGLGeometry.h"

#import <mbgl/annotation/annotation.hpp>
#import <mbgl/util/feature.hpp>
#import <vector>

#import <CoreGraphics/CoreGraphics.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@class VMGLPolygon;
@class VMGLPolyline;

@protocol VMGLMultiPointDelegate;

@interface VMGLMultiPoint (Private)

- (instancetype)initWithCoordinates:(const CLLocationCoordinate2D *)coords count:(NSUInteger)count;
- (BOOL)intersectsOverlayBounds:(VMGLCoordinateBounds)overlayBounds;

/** Constructs a shape annotation object, asking the delegate for style values. */
- (mbgl::Annotation)annotationObjectWithDelegate:(id <VMGLMultiPointDelegate>)delegate;

@end

/** An object that tells the MGLMultiPoint instance how to style itself. */
@protocol VMGLMultiPointDelegate <NSObject>

/** Returns the fill alpha value for the given annotation. */
- (double)alphaForShapeAnnotation:(VMGLShape *)annotation;

/** Returns the stroke color object for the given annotation. */
- (mbgl::Color)strokeColorForShapeAnnotation:(VMGLShape *)annotation;

/** Returns the fill color object for the given annotation. */
- (mbgl::Color)fillColorForPolygonAnnotation:(VMGLPolygon *)annotation;

/** Returns the stroke width object for the given annotation. */
- (CGFloat)lineWidthForPolylineAnnotation:(VMGLPolyline *)annotation;

@end

NS_ASSUME_NONNULL_END
