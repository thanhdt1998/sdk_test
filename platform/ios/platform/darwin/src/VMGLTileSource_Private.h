#import <CoreGraphics/CoreGraphics.h>

#import "VMGLFoundation.h"
#import "VMGLTileSource.h"

NS_ASSUME_NONNULL_BEGIN

namespace mbgl {
    class Tileset;
}

@class VMGLAttributionInfo;

@interface MGLTileSource (Private)

/**
 An HTML string to be displayed as attribution when the map is shown to a user.

 The default value is `nil`. If the source is initialized with a configuration
 URL, this property is also `nil` until the configuration JSON file is loaded.
 */
@property (nonatomic, copy, nullable, readonly) NSString *attributionHTMLString;

/**
 A structured representation of the `attribution` property. The default value is
 `nil`.

 @param fontSize The default text size in points, or 0 to use the default.
 @param linkColor The default link color, or `nil` to use the default.
 */
- (NSArray<VMGLAttributionInfo *> *)attributionInfosWithFontSize:(CGFloat)fontSize linkColor:(nullable MGLColor *)linkColor;

@end

MGL_EXPORT
mbgl::Tileset MGLTileSetFromTileURLTemplates(NSArray<NSString *> *tileURLTemplates, NSDictionary<MGLTileSourceOption, id> * _Nullable options);

NS_ASSUME_NONNULL_END
