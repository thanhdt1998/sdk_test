#import "VMGLCompactCalloutView.h"

#import "VMGLAnnotation.h"

@implementation VMGLCompactCalloutView
{
    id <VMGLAnnotation> _representedObject;
}

@synthesize representedObject = _representedObject;

+ (instancetype)platformCalloutView
{
    return [[self alloc] init];
}

- (BOOL)isAnchoredToAnnotation {
    return YES;
}

- (BOOL)dismissesAutomatically {
    return NO;
}

- (void)setRepresentedObject:(id <VMGLAnnotation>)representedObject
{
    _representedObject = representedObject;

    if ([representedObject respondsToSelector:@selector(title)])
    {
        self.title = representedObject.title;
    }
    if ([representedObject respondsToSelector:@selector(subtitle)])
    {
        self.subtitle = representedObject.subtitle;
    }
}

@end
