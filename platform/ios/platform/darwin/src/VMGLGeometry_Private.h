#import "VMGLGeometry.h"

#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
    #import <UIKit/UIKit.h>
#endif

#import <mbgl/util/geo.hpp>
#import <mbgl/util/geometry.hpp>

#import <array>
typedef double MGLLocationRadians;
typedef double MGLRadianDistance;
typedef double MGLRadianDirection;

/** Defines the coordinate by a `MGLRadianCoordinate2D`. */
typedef struct MGLRadianCoordinate2D {
    MGLLocationRadians latitude;
    MGLLocationRadians longitude;
} MGLRadianCoordinate2D;

/**
 Creates a new `MGLRadianCoordinate2D` from the given latitudinal and longitudinal.
 */
NS_INLINE MGLRadianCoordinate2D MGLRadianCoordinate2DMake(MGLLocationRadians latitude, MGLLocationRadians longitude) {
    MGLRadianCoordinate2D radianCoordinate;
    radianCoordinate.latitude = latitude;
    radianCoordinate.longitude = longitude;
    return radianCoordinate;
}

/// Returns the smallest rectangle that contains both the given rectangle and
/// the given point.
CGRect VMGLExtendRect(CGRect rect, CGPoint point);

#if TARGET_OS_IPHONE
NS_INLINE NSString *MGLStringFromSize(CGSize size) {
    return NSStringFromCGSize(size);
}
#else
NS_INLINE NSString *MGLStringFromSize(NSSize size) {
    return NSStringFromSize(size);
}
#endif

NS_INLINE NSString *VMGLStringFromCLLocationCoordinate2D(CLLocationCoordinate2D coordinate) {
    return [NSString stringWithFormat:@"(lat: %f, lon: %f)", coordinate.latitude, coordinate.longitude];
}

mbgl::LatLng VMGLLatLngFromLocationCoordinate2D(CLLocationCoordinate2D coordinate);

NS_INLINE mbgl::Point<double> VMGLPointFromLocationCoordinate2D(CLLocationCoordinate2D coordinate) {
    return mbgl::Point<double>(coordinate.longitude, coordinate.latitude);
}

NS_INLINE CLLocationCoordinate2D MGLLocationCoordinate2DFromPoint(mbgl::Point<double> point) {
    return CLLocationCoordinate2DMake(point.y, point.x);
}

NS_INLINE CLLocationCoordinate2D VMGLLocationCoordinate2DFromLatLng(mbgl::LatLng latLng) {
    return CLLocationCoordinate2DMake(latLng.latitude(), latLng.longitude());
}

NS_INLINE VMGLCoordinateBounds VMGLCoordinateBoundsFromLatLngBounds(mbgl::LatLngBounds latLngBounds) {
    return MGLCoordinateBoundsMake(VMGLLocationCoordinate2DFromLatLng(latLngBounds.southwest()),
                                   VMGLLocationCoordinate2DFromLatLng(latLngBounds.northeast()));
}

NS_INLINE mbgl::LatLngBounds VMGLLatLngBoundsFromCoordinateBounds(VMGLCoordinateBounds coordinateBounds) {
    return mbgl::LatLngBounds::hull(VMGLLatLngFromLocationCoordinate2D(coordinateBounds.sw),
                                    VMGLLatLngFromLocationCoordinate2D(coordinateBounds.ne));
}

NS_INLINE std::array<mbgl::LatLng, 4> MGLLatLngArrayFromCoordinateQuad(MGLCoordinateQuad quad) {
    return { VMGLLatLngFromLocationCoordinate2D(quad.topLeft),
    VMGLLatLngFromLocationCoordinate2D(quad.topRight),
    VMGLLatLngFromLocationCoordinate2D(quad.bottomRight),
    VMGLLatLngFromLocationCoordinate2D(quad.bottomLeft) };
}

NS_INLINE MGLCoordinateQuad MGLCoordinateQuadFromLatLngArray(std::array<mbgl::LatLng, 4> quad) {
    return { VMGLLocationCoordinate2DFromLatLng(quad[0]),
    VMGLLocationCoordinate2DFromLatLng(quad[3]),
    VMGLLocationCoordinate2DFromLatLng(quad[2]),
    VMGLLocationCoordinate2DFromLatLng(quad[1]) };
}

/**
 YES if the coordinate is valid or NO if it is not.
 Considers extended coordinates.
 */
NS_INLINE BOOL MGLLocationCoordinate2DIsValid(CLLocationCoordinate2D coordinate) {
    return (coordinate.latitude  <= 90.0  &&
            coordinate.latitude  >= -90.0  &&
            coordinate.longitude <= 360.0 &&
            coordinate.longitude >= -360.0);
}

#if TARGET_OS_IPHONE
    #define MGLEdgeInsets UIEdgeInsets
    #define MGLEdgeInsetsMake UIEdgeInsetsMake
#else
    #define MGLEdgeInsets NSEdgeInsets
    #define MGLEdgeInsetsMake NSEdgeInsetsMake
#endif

NS_INLINE mbgl::EdgeInsets VMGLEdgeInsetsFromNSEdgeInsets(MGLEdgeInsets insets) {
    return { insets.top, insets.left, insets.bottom, insets.right };
}

NS_INLINE MGLEdgeInsets NSEdgeInsetsFromMGLEdgeInsets(const mbgl::EdgeInsets& insets) {
    return MGLEdgeInsetsMake(insets.top(), insets.left(), insets.bottom(), insets.right());
}

/// Returns the combination of two edge insets.
NS_INLINE MGLEdgeInsets MGLEdgeInsetsInsetEdgeInset(MGLEdgeInsets base, MGLEdgeInsets inset) {
    return MGLEdgeInsetsMake(base.top + inset.top,
                             base.left + inset.left,
                             base.bottom + inset.bottom,
                             base.right + inset.right);
}

/** Returns MGLRadianCoordinate2D, converted from CLLocationCoordinate2D. */
NS_INLINE MGLRadianCoordinate2D MGLRadianCoordinateFromLocationCoordinate(CLLocationCoordinate2D locationCoordinate) {
    return MGLRadianCoordinate2DMake(VMGLRadiansFromDegrees(locationCoordinate.latitude),
                                     VMGLRadiansFromDegrees(locationCoordinate.longitude));
}

/**
 Returns the distance in radians given two coordinates.
 */
MGLRadianDistance MGLDistanceBetweenRadianCoordinates(MGLRadianCoordinate2D from, MGLRadianCoordinate2D to);

/**
 Returns direction in radians given two coordinates.
 */
MGLRadianDirection MGLRadianCoordinatesDirection(MGLRadianCoordinate2D from, MGLRadianCoordinate2D to);

/**
 Returns a coordinate at a given distance and direction away from coordinate.
 */
MGLRadianCoordinate2D MGLRadianCoordinateAtDistanceFacingDirection(MGLRadianCoordinate2D coordinate,
                                                                   MGLRadianDistance distance,
                                                                   MGLRadianDirection direction);

/**
 Returns the direction from one coordinate to another.
 */
CLLocationDirection MGLDirectionBetweenCoordinates(CLLocationCoordinate2D firstCoordinate, CLLocationCoordinate2D secondCoordinate);

/**
 Returns a point with coordinates rounded to the nearest logical pixel.
 */
CGPoint VMGLPointRounded(CGPoint point);

MGLMatrix4 MGLMatrix4Make(std::array<double, 16> mat);
