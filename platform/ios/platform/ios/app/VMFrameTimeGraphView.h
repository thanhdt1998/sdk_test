#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface VMFrameTimeGraphView : UIView

- (void)updatePathWithFrameDuration:(CFTimeInterval)frameDuration;

@end

NS_ASSUME_NONNULL_END
