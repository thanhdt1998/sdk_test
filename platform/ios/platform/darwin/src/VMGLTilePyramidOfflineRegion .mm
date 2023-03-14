#import "VMGLTilePyramidOfflineRegion .h"

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
    #import <Cocoa/Cocoa.h>
#endif

#import "VMGLOfflineRegion_Private.h"
#import "VMGLTilePyramidOfflineRegion_Private.h"
#import "VMGLGeometry_Private.h"
#import "VMGLStyle.h"
#import "VMGLLoggingConfiguration_Private.h"

@interface VMGLTilePyramidOfflineRegion  () <MGLOfflineRegion_Private, MGLTilePyramidOfflineRegion_Private>

@end

@implementation VMGLTilePyramidOfflineRegion  {
    NSURL *_styleURL;
}

@synthesize styleURL = _styleURL;
@synthesize includesIdeographicGlyphs = _includesIdeographicGlyphs;

-(NSDictionary *)offlineStartEventAttributes {
    return @{};
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)init {
    MGLLogInfo(@"Calling this initializer is not allowed.");
    [NSException raise:NSGenericException format:
     @"-[MGLTilePyramidOfflineRegion init] is unavailable. "
     @"Use -initWithStyleURL:bounds:fromZoomLevel:toZoomLevel: instead."];
    return nil;
}

- (instancetype)initWithStyleURL:(NSURL *)styleURL bounds:(VMGLCoordinateBounds)bounds fromZoomLevel:(double)minimumZoomLevel toZoomLevel:(double)maximumZoomLevel {
    MGLLogDebug(@"Initializing styleURL: %@ bounds: %@ fromZoomLevel: %f toZoomLevel: %f", styleURL, VMGLStringFromCoordinateBounds(bounds), minimumZoomLevel, maximumZoomLevel);
    if (self = [super init]) {
        if (!styleURL) {
            styleURL = [VMGLStyle defaultStyleURL];
        }

        if (!styleURL.scheme) {
            [NSException raise:MGLInvalidStyleURLException format:
             @"%@ does not support setting a relative file URL as the style URL. "
             @"To download the online resources required by this style, "
             @"specify a URL to an online copy of this style. "
             @"For Mapbox-hosted styles, use the mapbox: scheme.",
             NSStringFromClass([self class])];
        }

        _styleURL = styleURL;
        _bounds = bounds;
        _minimumZoomLevel = minimumZoomLevel;
        _maximumZoomLevel = maximumZoomLevel;
        _includesIdeographicGlyphs = NO;
    }
    return self;
}

- (instancetype)initWithOfflineRegionDefinition:(const mbgl::OfflineTilePyramidRegionDefinition &)definition {
    NSURL *styleURL = [NSURL URLWithString:@(definition.styleURL.c_str())];
    VMGLCoordinateBounds bounds = VMGLCoordinateBoundsFromLatLngBounds(definition.bounds);
    VMGLTilePyramidOfflineRegion * result = [self initWithStyleURL:styleURL bounds:bounds fromZoomLevel:definition.minZoom toZoomLevel:definition.maxZoom];
    result.includesIdeographicGlyphs = definition.includeIdeographs;
    return result;
}

- (const mbgl::OfflineRegionDefinition)offlineRegionDefinition {
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
    const float scaleFactor = [UIScreen instancesRespondToSelector:@selector(nativeScale)] ? [[UIScreen mainScreen] nativeScale] : [[UIScreen mainScreen] scale];
#elif TARGET_OS_MAC
    const float scaleFactor = [NSScreen mainScreen].backingScaleFactor;
#endif
    return mbgl::OfflineTilePyramidRegionDefinition(_styleURL.absoluteString.UTF8String,
                                                    VMGLLatLngBoundsFromCoordinateBounds(_bounds),
                                                    _minimumZoomLevel, _maximumZoomLevel,
                                                    scaleFactor, _includesIdeographicGlyphs);
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    MGLLogInfo(@"Initializing with coder.");
    NSURL *styleURL = [coder decodeObjectForKey:@"styleURL"];
    CLLocationCoordinate2D sw = CLLocationCoordinate2DMake([coder decodeDoubleForKey:@"southWestLatitude"],
                                                           [coder decodeDoubleForKey:@"southWestLongitude"]);
    CLLocationCoordinate2D ne = CLLocationCoordinate2DMake([coder decodeDoubleForKey:@"northEastLatitude"],
                                                           [coder decodeDoubleForKey:@"northEastLongitude"]);
    VMGLCoordinateBounds bounds = MGLCoordinateBoundsMake(sw, ne);
    double minimumZoomLevel = [coder decodeDoubleForKey:@"minimumZoomLevel"];
    double maximumZoomLevel = [coder decodeDoubleForKey:@"maximumZoomLevel"];

    VMGLTilePyramidOfflineRegion * result = [self initWithStyleURL:styleURL bounds:bounds fromZoomLevel:minimumZoomLevel toZoomLevel:maximumZoomLevel];
    result.includesIdeographicGlyphs = [coder decodeBoolForKey:@"includesIdeographicGlyphs"];
    return result;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_styleURL forKey:@"styleURL"];
    [coder encodeDouble:_bounds.sw.latitude forKey:@"southWestLatitude"];
    [coder encodeDouble:_bounds.sw.longitude forKey:@"southWestLongitude"];
    [coder encodeDouble:_bounds.ne.latitude forKey:@"northEastLatitude"];
    [coder encodeDouble:_bounds.ne.longitude forKey:@"northEastLongitude"];
    [coder encodeDouble:_maximumZoomLevel forKey:@"maximumZoomLevel"];
    [coder encodeDouble:_minimumZoomLevel forKey:@"minimumZoomLevel"];
    [coder encodeBool:_includesIdeographicGlyphs forKey:@"includesIdeographicGlyphs"];
}

- (id)copyWithZone:(nullable NSZone *)zone {
    VMGLTilePyramidOfflineRegion * result = [[[self class] allocWithZone:zone] initWithStyleURL:_styleURL bounds:_bounds fromZoomLevel:_minimumZoomLevel toZoomLevel:_maximumZoomLevel];
    result.includesIdeographicGlyphs = _includesIdeographicGlyphs;
    return result;
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[self class]]) {
        return NO;
    }

    VMGLTilePyramidOfflineRegion  *otherRegion = other;
    return (_minimumZoomLevel == otherRegion->_minimumZoomLevel
            && _maximumZoomLevel == otherRegion->_maximumZoomLevel
            && MGLCoordinateBoundsEqualToCoordinateBounds(_bounds, otherRegion->_bounds)
            && [_styleURL isEqual:otherRegion->_styleURL]
            && _includesIdeographicGlyphs == otherRegion->_includesIdeographicGlyphs);
}

- (NSUInteger)hash {
    return (_styleURL.hash
            + @(_bounds.sw.latitude).hash + @(_bounds.sw.longitude).hash
            + @(_bounds.ne.latitude).hash + @(_bounds.ne.longitude).hash
            + @(_minimumZoomLevel).hash + @(_maximumZoomLevel).hash
            + @(_includesIdeographicGlyphs).hash);
}

@end
