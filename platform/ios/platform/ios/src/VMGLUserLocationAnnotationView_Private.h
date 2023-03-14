#import "VMGLUserLocationAnnotationView.h"
#import "VMGLUserLocation.h"

NS_ASSUME_NONNULL_BEGIN

@class VMGLMapView;

@interface VMGLUserLocationAnnotationView (Private)

@property (nonatomic, weak, nullable) VMGLUserLocation *userLocation;
@property (nonatomic, weak, nullable) VMGLMapView *mapView;

@end

NS_ASSUME_NONNULL_END
