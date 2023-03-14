#import "VMGLUserLocation.h"

#import <CoreLocation/CoreLocation.h>

@class VMGLMapView;

NS_ASSUME_NONNULL_BEGIN

@interface VMGLUserLocation (Private)

@property (nonatomic, weak) VMGLMapView *mapView;
@property (nonatomic, readwrite, nullable) CLLocation *location;
@property (nonatomic, readwrite, nullable) CLHeading *heading;

- (instancetype)initWithMapView:(VMGLMapView *)mapView;

@end

NS_ASSUME_NONNULL_END
