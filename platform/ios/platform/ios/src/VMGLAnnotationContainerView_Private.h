#import "VMGLAnnotationContainerView.h"
#import "VMGLAnnotationView.h"

@class VMGLAnnotationView;

NS_ASSUME_NONNULL_BEGIN

@interface VMGLAnnotationContainerView (Private)

@property (nonatomic) NSMutableArray<VMGLAnnotationView *> *annotationViews;

@end

NS_ASSUME_NONNULL_END
