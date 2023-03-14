#import <UIKit/UIKit.h>

#import "VMGLFoundation.h"

NS_ASSUME_NONNULL_BEGIN

@protocol VMGLFeature;

/// Unique identifier representing a single annotation in mbgl.
typedef uint64_t VMGLAnnotationTag;

/** An accessibility element representing something that appears on the map. */
MGL_EXPORT
@interface MGLMapAccessibilityElement : UIAccessibilityElement

@end

/** An accessibility element representing a map annotation. */
@interface VMGLAnnotationAccessibilityElement : MGLMapAccessibilityElement

/** The tag of the annotation represented by this element. */
@property (nonatomic) VMGLAnnotationTag tag;

- (instancetype)initWithAccessibilityContainer:(id)container tag:(VMGLAnnotationTag)identifier NS_DESIGNATED_INITIALIZER;

@end

/** An accessibility element representing a map feature. */
MGL_EXPORT
@interface VMGLFeatureAccessibilityElement : MGLMapAccessibilityElement

/** The feature represented by this element. */
@property (nonatomic, strong) id <VMGLFeature> feature;

- (instancetype)initWithAccessibilityContainer:(id)container feature:(id <VMGLFeature>)feature NS_DESIGNATED_INITIALIZER;

@end

/** An accessibility element representing a place feature. */
MGL_EXPORT
@interface VMGLPlaceFeatureAccessibilityElement : VMGLFeatureAccessibilityElement
@end

/** An accessibility element representing a road feature. */
MGL_EXPORT
@interface VMGLRoadFeatureAccessibilityElement : VMGLFeatureAccessibilityElement
@end

/** An accessibility element representing the MGLMapView at large. */
MGL_EXPORT
@interface VMGLMapViewProxyAccessibilityElement : UIAccessibilityElement
@end

NS_ASSUME_NONNULL_END
