#import "VMGLAnnotationContainerView.h"
#import "VMGLAnnotationView.h"

@interface VMGLAnnotationContainerView ()

@property (nonatomic) NSMutableArray<VMGLAnnotationView *> *annotationViews;

@end

@implementation VMGLAnnotationContainerView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _annotationViews = [NSMutableArray array];
    }
    return self;
}

+ (instancetype)annotationContainerViewWithAnnotationContainerView:(nonnull VMGLAnnotationContainerView *)annotationContainerView
{
    VMGLAnnotationContainerView *newAnnotationContainerView = [[VMGLAnnotationContainerView alloc] initWithFrame:annotationContainerView.frame];
    [newAnnotationContainerView addSubviews:annotationContainerView.subviews];
    return newAnnotationContainerView;
}

- (void)addSubviews:(NSArray<VMGLAnnotationView *> *)subviews
{
    for (VMGLAnnotationView *view in subviews)
    {
        [self addSubview:view];
        [self.annotationViews addObject:view];
    }
}

#pragma mark UIAccessibility methods

- (UIAccessibilityTraits)accessibilityTraits {
    return UIAccessibilityTraitAdjustable;
}

- (void)accessibilityIncrement {
    [self.superview.superview accessibilityIncrement];
}

- (void)accessibilityDecrement {
    [self.superview.superview accessibilityDecrement];
}

@end
