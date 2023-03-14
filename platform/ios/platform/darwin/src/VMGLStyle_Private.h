#import "VMGLStyle.h"

#import "VMGLStyleLayer.h"
#import "VMGLFillStyleLayer.h"

NS_ASSUME_NONNULL_BEGIN

namespace mbgl {
    namespace style {
        class Style;
    }
}

@class VMGLAttributionInfo;
@class VMGLMapView;
@class MGLOpenGLStyleLayer;
@class MGLVectorTileSource;
@class MGLVectorStyleLayer;

@interface VMGLStyle (Private)

- (instancetype)initWithRawStyle:(mbgl::style::Style *)rawStyle stylable:(id <VMGLStylable>)stylable;

@property (nonatomic, readonly, weak) id <VMGLStylable> stylable;
@property (nonatomic, readonly) mbgl::style::Style *rawStyle;

- (nullable NSArray<VMGLAttributionInfo *> *)attributionInfosWithFontSize:(CGFloat)fontSize linkColor:(nullable MGLColor *)linkColor;
@property (nonatomic, readonly, strong) NSMutableDictionary<NSString *, MGLOpenGLStyleLayer *> *openGLLayers;
- (void)setStyleClasses:(NSArray<NSString *> *)appliedClasses transitionDuration:(NSTimeInterval)transitionDuration;

@end

@interface VMGLStyle (MGLStreetsAdditions)

@property (nonatomic, readonly, copy) NSArray<MGLVectorStyleLayer *> *placeStyleLayers;
@property (nonatomic, readonly, copy) NSArray<MGLVectorStyleLayer *> *roadStyleLayers;

@end

NS_ASSUME_NONNULL_END
