#import "VMGLPolygon_Private.h"

#import "VMGLMultiPoint_Private.h"
#import "VMGLGeometry_Private.h"
#import "VMGLLoggingConfiguration_Private.h"

#import "VMGLFeature.h"

#import <mbgl/util/geojson.hpp>
#import <mapbox/polylabel.hpp>

@implementation VMGLPolygon

@dynamic overlayBounds;

+ (instancetype)polygonWithCoordinates:(const CLLocationCoordinate2D *)coords count:(NSUInteger)count {
    return [self polygonWithCoordinates:coords count:count interiorPolygons:nil];
}

+ (instancetype)polygonWithCoordinates:(const CLLocationCoordinate2D *)coords count:(NSUInteger)count interiorPolygons:(NSArray<VMGLPolygon *> *)interiorPolygons {
    return [[self alloc] initWithCoordinates:coords count:count interiorPolygons:interiorPolygons];
}

- (instancetype)initWithCoordinates:(const CLLocationCoordinate2D *)coords count:(NSUInteger)count interiorPolygons:(NSArray<VMGLPolygon *> *)interiorPolygons {
    MGLLogDebug(@"Initializing with %lu coordinates and %lu interiorPolygons.", (unsigned long)count, (unsigned long)interiorPolygons);
    if (self = [super initWithCoordinates:coords count:count]) {
        if (interiorPolygons.count) {
            _interiorPolygons = interiorPolygons;
        }
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    MGLLogInfo(@"Initializng with coder.");
    self = [super initWithCoder:decoder];
    if (self) {
        _interiorPolygons = [decoder decodeObjectOfClass:[NSArray class] forKey:@"interiorPolygons"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeObject:self.interiorPolygons forKey:@"interiorPolygons"];
}

- (BOOL)isEqual:(id)other {
    if (self == other) return YES;
    if (![other isKindOfClass:[VMGLPolygon class]]) return NO;

    VMGLPolygon *otherPolygon = (VMGLPolygon *)other;
    return ([super isEqual:otherPolygon] &&
            [[self geoJSONDictionary] isEqualToDictionary:[otherPolygon geoJSONDictionary]]);
}

- (NSUInteger)hash {
    return [super hash] + [[self geoJSONDictionary] hash];
}

- (CLLocationCoordinate2D)coordinate {
    // pole of inaccessibility
    auto poi = mapbox::polylabel([self polygon]);
    
    return MGLLocationCoordinate2DFromPoint(poi);
}

- (mbgl::LinearRing<double>)ring {
    NSUInteger count = self.pointCount;
    CLLocationCoordinate2D *coordinates = self.coordinates;

    mbgl::LinearRing<double> result;
    result.reserve(self.pointCount);
    for (NSUInteger i = 0; i < count; i++) {
        result.push_back(mbgl::Point<double>(coordinates[i].longitude, coordinates[i].latitude));
    }
    return result;
}

- (mbgl::Polygon<double>)polygon {
    mbgl::Polygon<double> geometry;
    geometry.push_back(self.ring);
    for (VMGLPolygon *polygon in self.interiorPolygons) {
        geometry.push_back(polygon.ring);
    }
    return geometry;
}

- (mbgl::Geometry<double>)geometryObject {
    return [self polygon];
}

- (mbgl::Annotation)annotationObjectWithDelegate:(id <VMGLMultiPointDelegate>)delegate {

    mbgl::FillAnnotation annotation { [self polygon] };
    annotation.opacity = { static_cast<float>([delegate alphaForShapeAnnotation:self]) };
    annotation.outlineColor = { [delegate strokeColorForShapeAnnotation:self] };
    annotation.color = { [delegate fillColorForPolygonAnnotation:self] };

    return annotation;
}

- (NSDictionary *)geoJSONDictionary {
    return @{@"type": @"Polygon",
             @"coordinates": self.mgl_coordinates};
}

- (NSArray<id> *)mgl_coordinates {
    NSMutableArray *coordinates = [NSMutableArray array];

    NSMutableArray *exteriorRing = [NSMutableArray array];
    for (NSUInteger index = 0; index < self.pointCount; index++) {
        CLLocationCoordinate2D coordinate = self.coordinates[index];
        [exteriorRing addObject:@[@(coordinate.longitude), @(coordinate.latitude)]];
    }
    [coordinates addObject:exteriorRing];

    for (VMGLPolygon *interiorPolygon in self.interiorPolygons) {
        NSMutableArray *interiorRing = [NSMutableArray array];
        for (NSUInteger index = 0; index < interiorPolygon.pointCount; index++) {
            CLLocationCoordinate2D coordinate = interiorPolygon.coordinates[index];
            [interiorRing addObject:@[@(coordinate.longitude), @(coordinate.latitude)]];
        }
        [coordinates addObject:interiorRing];
    }

    return [coordinates copy];
}

@end

@interface VMGLMultiPolygon ()

@property (nonatomic, copy, readwrite) NSArray<VMGLPolygon *> *polygons;

@end

@implementation VMGLMultiPolygon {
    VMGLCoordinateBounds _overlayBounds;
}

@synthesize overlayBounds = _overlayBounds;

+ (instancetype)multiPolygonWithPolygons:(NSArray<VMGLPolygon *> *)polygons {
    return [[self alloc] initWithPolygons:polygons];
}

- (instancetype)initWithPolygons:(NSArray<VMGLPolygon *> *)polygons {
    MGLLogDebug(@"Initializing with %lu polygons.", (unsigned long)polygons.count);
    if (self = [super init]) {
        _polygons = polygons;

        mbgl::LatLngBounds bounds = mbgl::LatLngBounds::empty();

        for (VMGLPolygon *polygon in _polygons) {
            bounds.extend(VMGLLatLngBoundsFromCoordinateBounds(polygon.overlayBounds));
        }
        _overlayBounds = VMGLCoordinateBoundsFromLatLngBounds(bounds);
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    MGLLogInfo(@"Initializing with coder.");
    if (self = [super initWithCoder:decoder]) {
        _polygons = [decoder decodeObjectOfClass:[NSArray class] forKey:@"polygons"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeObject:_polygons forKey:@"polygons"];
}

- (BOOL)isEqual:(id)other {
    if (self == other) return YES;
    if (![other isKindOfClass:[VMGLMultiPolygon class]]) return NO;

    VMGLMultiPolygon *otherMultiPolygon = other;
    return [super isEqual:other]
    && [self.polygons isEqualToArray:otherMultiPolygon.polygons];
}

- (NSUInteger)hash {
    NSUInteger hash = [super hash];
    for (VMGLPolygon *polygon in self.polygons) {
        hash += [polygon hash];
    }
    return hash;
}

- (CLLocationCoordinate2D)coordinate {
    VMGLPolygon *firstPolygon = self.polygons.firstObject;
    
    return firstPolygon.coordinate;
}

- (BOOL)intersectsOverlayBounds:(VMGLCoordinateBounds)overlayBounds {
    return MGLCoordinateBoundsIntersectsCoordinateBounds(_overlayBounds, overlayBounds);
}

- (mbgl::MultiPolygon<double>)multiPolygon {
    mbgl::MultiPolygon<double> multiPolygon;
    multiPolygon.reserve(self.polygons.count);
    for (VMGLPolygon *polygon in self.polygons) {
        mbgl::Polygon<double> geometry;
        geometry.push_back(polygon.ring);
        for (VMGLPolygon *interiorPolygon in polygon.interiorPolygons) {
            geometry.push_back(interiorPolygon.ring);
        }
        multiPolygon.push_back(geometry);
    }
    return multiPolygon;
}

- (mbgl::Geometry<double>)geometryObject {
    return [self multiPolygon];
}

- (NSDictionary *)geoJSONDictionary {
    NSMutableArray *coordinates = [[NSMutableArray alloc] initWithCapacity:self.polygons.count];
    for (MGLPolygonFeature *feature in self.polygons) {
        [coordinates addObject: feature.mgl_coordinates];
    }
    return @{@"type": @"MultiPolygon",
             @"coordinates": coordinates};
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; title = %@, subtitle: = %@, count = %lu; bounds = %@>",
            NSStringFromClass([self class]), (void *)self,
            self.title ? [NSString stringWithFormat:@"\"%@\"", self.title] : self.title,
            self.subtitle ? [NSString stringWithFormat:@"\"%@\"", self.subtitle] : self.subtitle,
            (unsigned long)self.polygons.count,
            VMGLStringFromCoordinateBounds(self.overlayBounds)];
}

@end
