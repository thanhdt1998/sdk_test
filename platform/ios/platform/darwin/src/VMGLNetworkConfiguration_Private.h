#import "VMGLNetworkConfiguration.h"
#include <mbgl/interface/native_apple_interface.h>

NS_ASSUME_NONNULL_BEGIN

@class VMGLNetworkConfiguration;
@protocol MGLNetworkConfigurationMetricsDelegate <NSObject>

- (void)networkConfiguration:(VMGLNetworkConfiguration *)networkConfiguration didGenerateMetricEvent:(NSDictionary *)metricEvent;

@end

extern NSString * const kMGLDownloadPerformanceEvent;

@interface VMGLNetworkConfiguration (Private)

@property (nonatomic, strong) NSMutableDictionary<NSString*, NSDictionary*> *events;
@property (nonatomic, weak) id<MGLNetworkConfigurationMetricsDelegate> metricsDelegate;

- (void)resetNativeNetworkManagerDelegate;
- (void)startDownloadEvent:(NSString *)urlString type:(NSString *)resourceType;
- (void)stopDownloadEventForResponse:(NSURLResponse *)response;
- (void)cancelDownloadEventForResponse:(NSURLResponse *)response;
@end

NS_ASSUME_NONNULL_END
