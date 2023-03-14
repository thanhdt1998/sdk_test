#import "VMGLPointCollection.h"

NS_ASSUME_NONNULL_BEGIN

@interface VMGLPointCollection (Private)

- (instancetype)initWithCoordinates:(const CLLocationCoordinate2D *)coords count:(NSUInteger)count;

@end

NS_ASSUME_NONNULL_END
