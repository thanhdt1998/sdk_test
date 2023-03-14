#import <UIKit/UIKit.h>

#import "VMGLTypes.h"

@class VMGLAnnotationView;

NS_ASSUME_NONNULL_BEGIN

@interface VMGLAnnotationContainerView : UIView

+ (instancetype)annotationContainerViewWithAnnotationContainerView:(VMGLAnnotationContainerView *)annotationContainerView;

- (void)addSubviews:(NSArray<VMGLAnnotationView *> *)subviews;

@end

NS_ASSUME_NONNULL_END
