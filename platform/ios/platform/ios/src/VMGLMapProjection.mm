#include <mbgl/map/map.hpp>
#include <mbgl/map/map_projection.hpp>
#include <mbgl/util/geo.hpp>
#include <mbgl/util/projection.hpp>

#import "VMGLMapProjection.h"
#import "VMGLMapView_Private.h"
#import "VMGLGeometry_Private.h"

@interface VMGLMapProjection ()

@property (nonatomic) CGSize mapFrameSize;

@end

@implementation VMGLMapProjection
{
    std::unique_ptr<mbgl::MapProjection> _mbglProjection;
}

- (instancetype)initWithMapView:(VMGLMapView *)mapView
{
    if (self = [super init])
    {
        _mbglProjection = std::make_unique<mbgl::MapProjection>([mapView vmglMap]);
        self.mapFrameSize = mapView.frame.size;
    }
    return self;
}

- (VMGLMapCamera*)camera
{
    mbgl::CameraOptions cameraOptions = _mbglProjection->getCamera();

    CLLocationCoordinate2D centerCoordinate = VMGLLocationCoordinate2DFromLatLng(*cameraOptions.center);
    double zoomLevel = *cameraOptions.zoom;
    CLLocationDirection direction = mbgl::util::wrap(*cameraOptions.bearing, 0., 360.);
    CGFloat pitch = *cameraOptions.pitch;
    CLLocationDistance altitude = MGLAltitudeForZoomLevel(zoomLevel, pitch,
                                                          centerCoordinate.latitude, self.mapFrameSize);
    return [VMGLMapCamera cameraLookingAtCenterCoordinate:centerCoordinate altitude:altitude
                                                   pitch:pitch heading:direction];
}

- (void)setCamera:(VMGLMapCamera * _Nonnull)camera withEdgeInsets:(UIEdgeInsets)insets
{
    mbgl::CameraOptions cameraOptions;
    if (CLLocationCoordinate2DIsValid(camera.centerCoordinate))
    {
        cameraOptions.center = VMGLLatLngFromLocationCoordinate2D(camera.centerCoordinate);
    }
    cameraOptions.padding = VMGLEdgeInsetsFromNSEdgeInsets(insets);
    cameraOptions.zoom = VMGLZoomLevelForAltitude(camera.altitude, camera.pitch,
                                                 camera.centerCoordinate.latitude,
                                                 self.mapFrameSize);
    if (camera.heading >= 0)
    {
        cameraOptions.bearing = camera.heading;
    }
    if (camera.pitch >= 0)
    {
        cameraOptions.pitch = camera.pitch;
    }

    _mbglProjection->setCamera(cameraOptions);
}

- (void)setVisibleCoordinateBounds:(VMGLCoordinateBounds)bounds edgePadding:(UIEdgeInsets)insets {
    CLLocationCoordinate2D coordinates[] = {
        {bounds.ne.latitude, bounds.sw.longitude},
        bounds.sw,
        {bounds.sw.latitude, bounds.ne.longitude},
        bounds.ne,
    };

    mbgl::EdgeInsets padding = VMGLEdgeInsetsFromNSEdgeInsets(insets);
    std::vector<mbgl::LatLng> latLngs;
    latLngs.reserve(4);
    for (NSUInteger i = 0; i < 4; i++)
    {
        latLngs.push_back({coordinates[i].latitude, coordinates[i].longitude});
    }

    _mbglProjection->setVisibleCoordinates(latLngs, padding);
}

- (CLLocationCoordinate2D)convertPoint:(CGPoint)point
{
    mbgl::ScreenCoordinate screenCoordinate = mbgl::ScreenCoordinate(point.x, point.y);
    return VMGLLocationCoordinate2DFromLatLng(_mbglProjection->latLngForPixel(screenCoordinate).wrapped());
}

- (CGPoint)convertCoordinate:(CLLocationCoordinate2D)coordinate
{
    if ( !CLLocationCoordinate2DIsValid(coordinate))
    {
        return CGPointMake(NAN, NAN);
    }

    mbgl::LatLng latLng = VMGLLatLngFromLocationCoordinate2D(coordinate);
    mbgl::ScreenCoordinate pixel = _mbglProjection->pixelForLatLng(latLng);
    return CGPointMake(pixel.x, pixel.y);
}

- (CLLocationDistance)metersPerPoint
{
    mbgl::CameraOptions cameraOptions = _mbglProjection->getCamera();
    return mbgl::Projection::getMetersPerPixelAtLatitude(cameraOptions.center->latitude(),
                                                         *cameraOptions.zoom);
}


@end
