#import "VMGLAnnotationImage.h"

NS_ASSUME_NONNULL_BEGIN

@protocol VMGLAnnotationImageDelegate <NSObject>

@required
- (void)annotationImageNeedsRedisplay:(VMGLAnnotationImage *)annotationImage;

@end

@interface VMGLAnnotationImage (Private)

/// Unique identifier of the sprite image used by the style to represent the receiver’s `image`.
@property (nonatomic, strong, nullable) NSString *styleIconIdentifier;

@property (nonatomic, weak) id<VMGLAnnotationImageDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
