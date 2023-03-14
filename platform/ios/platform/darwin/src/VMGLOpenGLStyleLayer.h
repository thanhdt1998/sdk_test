#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <QuartzCore/QuartzCore.h>

#import "VMGLFoundation.h"
#import "VMGLStyleValue.h"
#import "VMGLStyleLayer.h"
#import "VMGLGeometry.h"

NS_ASSUME_NONNULL_BEGIN

@class VMGLMapView;
@class VMGLStyle;

typedef struct MGLStyleLayerDrawingContext {
    CGSize size;
    CLLocationCoordinate2D centerCoordinate;
    double zoomLevel;
    CLLocationDirection direction;
    CGFloat pitch;
    CGFloat fieldOfView;
    MGLMatrix4 projectionMatrix;
} MGLStyleLayerDrawingContext;

MGL_EXPORT
@interface MGLOpenGLStyleLayer : MGLStyleLayer

@property (nonatomic, weak, readonly) VMGLStyle *style;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#if TARGET_OS_IPHONE
@property (nonatomic, readonly) EAGLContext *context;
#else
@property (nonatomic, readonly) CGLContextObj context;
#endif
#pragma clang diagnostic pop

- (instancetype)initWithIdentifier:(NSString *)identifier;

- (void)didMoveToMapView:(VMGLMapView *)mapView;

- (void)willMoveFromMapView:(VMGLMapView *)mapView;

- (void)drawInMapView:(VMGLMapView *)mapView withContext:(MGLStyleLayerDrawingContext)context;

- (void)setNeedsDisplay;

@end

NS_ASSUME_NONNULL_END
