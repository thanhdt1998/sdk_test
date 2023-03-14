#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreLocation/CoreLocation.h>

#import "VMGLAttributionInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface VMGLAttributionInfo (Private)

/**
 Parses and returns the attribution infos contained in the given HTML source
 code string.

 @param htmlString The HTML source code to parse.
 @param fontSize The default text size in points.
 @param linkColor The default link color.
 */
+ (NSArray<VMGLAttributionInfo *> *)attributionInfosFromHTMLString:(nullable NSString *)htmlString fontSize:(CGFloat)fontSize linkColor:(nullable MGLColor *)linkColor;

+ (NSAttributedString *)attributedStringForAttributionInfos:(NSArray<VMGLAttributionInfo *> *)attributionInfos;

@end

@interface NSMutableArray (MGLAttributionInfoAdditions)

/**
 Adds the given attribution info object to the receiver as long as it isn’t
 redundant to any object already in the receiver. Any existing object that is
 redundant to the given object is replaced by the given object.

 @param info The info object to add to the receiver.
 */
- (void)growArrayByAddingAttributionInfo:(VMGLAttributionInfo *)info;

/**
 Adds each of the given attribution info objects to the receiver as long as it
 isn’t redundant to any object already in the receiver. Any existing object that
 is redundant to the given object is replaced by the given object.

 @param infos An array of info objects to add to the receiver.
 */
- (void)growArrayByAddingAttributionInfosFromArray:(NSArray<VMGLAttributionInfo *> *)infos;

@end

NS_ASSUME_NONNULL_END
