#import "VMGLAnnotationView.h"
#import "VMGLAnnotation.h"

NS_ASSUME_NONNULL_BEGIN

@class VMGLMapView;

@interface VMGLAnnotationView (Private)

@property (nonatomic, readwrite, nullable) NSString *reuseIdentifier;
@property (nonatomic, weak) VMGLMapView *mapView;

@end

NS_ASSUME_NONNULL_END
