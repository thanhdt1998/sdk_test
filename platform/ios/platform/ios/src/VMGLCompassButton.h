#import <UIKit/UIKit.h>

#import "VMGLTypes.h"

NS_ASSUME_NONNULL_BEGIN

/**
 A specialized view that displays the current compass heading for its associated map.
 */
MGL_EXPORT
@interface VMGLCompassButton : UIImageView

/**
 The visibility of the compass button.

 You can configure a compass button to be visible all the time or only when the compass heading changes.
 */
@property (nonatomic, assign) MGLOrnamentVisibility compassVisibility;

@end

NS_ASSUME_NONNULL_END
