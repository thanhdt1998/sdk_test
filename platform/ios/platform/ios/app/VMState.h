@import Mapbox;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSString *const MBXCamera;
FOUNDATION_EXTERN NSString *const MBXShowsUserLocation;
FOUNDATION_EXTERN NSString *const MBXUserTrackingMode;
FOUNDATION_EXTERN NSString *const MBXMapShowsHeadingIndicator;
FOUNDATION_EXTERN NSString *const MBXShowsMapScale;
FOUNDATION_EXTERN NSString *const MBXShowsZoomLevelOrnament;
FOUNDATION_EXTERN NSString *const MBXShowsTimeFrameGraph;
FOUNDATION_EXTERN NSString *const MBXMapFramerateMeasurementEnabled;
FOUNDATION_EXTERN NSString *const MBXDebugMaskValue;
FOUNDATION_EXTERN NSString *const MBXReuseQueueStatsEnabled;

@interface VMState : NSObject <NSSecureCoding>

@property (nonatomic, nullable) VMGLMapCamera *camera;
@property (nonatomic) BOOL showsUserLocation;
@property (nonatomic) VMGLUserTrackingMode userTrackingMode;
@property (nonatomic) BOOL showsUserHeadingIndicator;
@property (nonatomic) BOOL showsMapScale;
@property (nonatomic) BOOL showsZoomLevelOrnament;
@property (nonatomic) BOOL showsTimeFrameGraph;
@property (nonatomic) BOOL framerateMeasurementEnabled;
@property (nonatomic) VMGLMapDebugMaskOptions debugMask;
@property (nonatomic) BOOL reuseQueueStatsEnabled;

@property (nonatomic, readonly) NSString *debugDescription;

@end

NS_ASSUME_NONNULL_END
