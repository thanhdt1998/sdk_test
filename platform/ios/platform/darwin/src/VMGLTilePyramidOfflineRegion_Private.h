#import <Foundation/Foundation.h>

#import "VMGLOfflineRegion.h"

#include <mbgl/storage/offline.hpp>

NS_ASSUME_NONNULL_BEGIN

@protocol MGLTilePyramidOfflineRegion_Private <VMOfflineRegion>

/**
 Initializes and returns an offline region backed by the given C++ region
 definition object.

 @param definition A reference to an offline region definition backing the
    offline region.
 */
- (instancetype)initWithOfflineRegionDefinition:(const mbgl::OfflineTilePyramidRegionDefinition &)definition;

@end

NS_ASSUME_NONNULL_END
