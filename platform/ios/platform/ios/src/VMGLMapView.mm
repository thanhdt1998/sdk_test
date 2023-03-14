#import "VMGLMapView_Private.h"
#import "VMGLMapView+Impl.h"

#include <mbgl/map/map.hpp>
#include <mbgl/map/map_options.hpp>
#include <mbgl/annotation/annotation.hpp>
#include <mbgl/map/camera.hpp>
#include <mbgl/map/mode.hpp>
#include <mbgl/util/platform.hpp>
#include <mbgl/storage/resource_options.hpp>
#include <mbgl/storage/network_status.hpp>
#include <mbgl/style/style.hpp>
#include <mbgl/style/image.hpp>
#include <mbgl/style/transition_options.hpp>
#include <mbgl/gl/custom_layer.hpp>
#include <mbgl/renderer/renderer.hpp>
#include <mbgl/math/wrap.hpp>
#include <mbgl/util/client_options.hpp>
#include <mbgl/util/exception.hpp>
#include <mbgl/util/geo.hpp>
#include <mbgl/util/constants.hpp>
#include <mbgl/util/image.hpp>
#include <mbgl/util/projection.hpp>
#include <mbgl/util/chrono.hpp>
#include <mbgl/util/run_loop.hpp>
#include <mbgl/util/string.hpp>
#include <mbgl/util/projection.hpp>

#import "Mapbox.h"
#import "VMGLShape_Private.h"
#import "VMGLFeature_Private.h"
#import "VMGLGeometry_Private.h"
#import "VMGLMultiPoint_Private.h"
#import "VMGLOfflineStorage_Private.h"
#import "VMGLVectorTileSource_Private.h"
#import "VMGLFoundation_Private.h"
#import "VMGLRendererFrontend.h"
#import "VMGLRendererConfiguration.h"

#import "NSBundle+MGLAdditions.h"
#import "NSDate+MGLAdditions.h"
#import "NSException+MGLAdditions.h"
#import "NSPredicate+MGLPrivateAdditions.h"
#import "NSString+MGLAdditions.h"
#import "NSURL+MGLAdditions.h"
#import "UIDevice+MGLAdditions.h"
#import "UIImage+MGLAdditions.h"
#import "UIViewController+MGLAdditions.h"
#import "UIView+MGLAdditions.h"

#import "VMGLFaux3DUserLocationAnnotationView.h"
#import "VMGLUserLocationAnnotationView.h"
#import "VMGLUserLocationAnnotationView_Private.h"
#import "VMGLUserLocation_Private.h"
#import "VMGLAnnotationImage_Private.h"
#import "VMGLAnnotationView_Private.h"
#import "VMGLCompassButton_Private.h"
#import "VMGLScaleBar.h"
#import "VMGLStyle_Private.h"
#import "VMGLStyleLayer_Private.h"
#import "VMGLCompactCalloutView.h"
#import "VMGLAnnotationContainerView.h"
#import "VMGLAnnotationContainerView_Private.h"
#import "VMGLAttributionInfo_Private.h"
#import "VMGLMapAccessibilityElement.h"
#import "VMGLLocationManager_Private.h"
#import "VMGLLoggingConfiguration_Private.h"
#import "VMGLNetworkConfiguration_Private.h"
#import "VMGLReachability.h"
#import "VMGLSettings_Private.h"
#import "VMGLMapProjection.h"

#include <algorithm>
#include <cstdlib>
#include <map>
#include <unordered_set>

class VMGLAnnotationContext;

const VMGLMapViewDecelerationRate VMGLMapViewDecelerationRateNormal = UIScrollViewDecelerationRateNormal;
const VMGLMapViewDecelerationRate VMGLMapViewDecelerationRateFast = UIScrollViewDecelerationRateFast;
const VMGLMapViewDecelerationRate VMGLMapViewDecelerationRateImmediate = 0.0;

const VMGLMapViewPreferredFramesPerSecond VMGLMapViewPreferredFramesPerSecondDefault = -1;
const VMGLMapViewPreferredFramesPerSecond VMGLMapViewPreferredFramesPerSecondLowPower = 30;
const VMGLMapViewPreferredFramesPerSecond VMGLMapViewPreferredFramesPerSecondMaximum = 0;

const VMGLExceptionName VMGLMissingLocationServicesUsageDescriptionException = @"MGLMissingLocationServicesUsageDescriptionException";
const VMGLExceptionName VMGLUserLocationAnnotationTypeException = @"MGLUserLocationAnnotationTypeException";
const VMGLExceptionName VMGLUnderlyingMapUnavailableException = @"MGLUnderlyingMapUnavailableException";

const CGPoint VMGLOrnamentDefaultPositionOffset = CGPointMake(8, 8);

/// Indicates the manner in which the map view is tracking the user location.
typedef NS_ENUM(NSUInteger, VMGLUserTrackingState) {
    /// The map view is not yet tracking the user location.
    VMGLUserTrackingStatePossible = 0,
    /// The map view has begun to move to the first reported user location.
    VMGLUserTrackingStateBegan,
    /// The map view begins a significant transition.
    VMGLUserTrackingStateBeginSignificantTransition,
    /// The map view has finished moving to the first reported user location.
    VMGLUserTrackingStateChanged,
};

const NSTimeInterval VMGLAnimationDuration = 0.3;

/// Duration of an animation due to a user location update, typically chosen to
/// match a typical interval between user location updates.
const NSTimeInterval VMGLUserLocationAnimationDuration = 1.0;

/// Distance between the map view’s edge and that of the user location
/// annotation view.
const UIEdgeInsets VMGLUserLocationAnnotationViewInset = UIEdgeInsetsMake(50, 0, 50, 0);

const CGSize VMGLAnnotationUpdateViewportOutset = {150, 150};
const CGFloat MGLMinimumZoom = 3;

/// Minimum initial zoom level when entering user tracking mode.
const double VMGLMinimumZoomLevelForUserTracking = 10.5;

/// Initial zoom level when entering user tracking mode from a low zoom level.
const double VMGLDefaultZoomLevelForUserTracking = 14.0;

/// Tolerance for snapping to true north, measured in degrees in either direction.
const CLLocationDirection VMGLToleranceForSnappingToNorth = 7;

/// Distance threshold to stop the camera while animating.
const CLLocationDistance VMGLDistanceThresholdForCameraPause = 500;

/// Rotation threshold while a pinch gesture is occurring.
static NSString * const VMGLRotationThresholdWhileZoomingKey = @"MGLRotationThresholdWhileZooming";

/// Reuse identifier and file name of the default point annotation image.
static NSString * const VMGLDefaultStyleMarkerSymbolName = @"default_marker";

/// Reuse identifier and file name of the invisible point annotation image used
/// by annotations that are visually backed by MGLAnnotationView objects
static NSString * const VMGLInvisibleStyleMarkerSymbolName = @"invisible_marker";

/// Prefix that denotes a sprite installed by MGLMapView, to avoid collisions
/// with style-defined sprites.
NSString * const VMGLAnnotationSpritePrefix = @"com.mapbox.sprites.";

/// Slop area around the hit testing point, allowing for imprecise annotation selection.
const CGFloat VMGLAnnotationImagePaddingForHitTest = 5;

/// Distance from the callout’s anchor point to the annotation it points to.
const CGFloat VMGLAnnotationImagePaddingForCallout = 1;

const CGSize VMGLAnnotationAccessibilityElementMinimumSize = CGSizeMake(10, 10);

/// The number of view annotations (excluding the user location view) that must
/// be descendents of `MGLMapView` before presentsWithTransaction is enabled.
static const NSUInteger VMGLPresentsWithTransactionAnnotationCount = 0;

/// An indication that the requested annotation was not found or is nonexistent.
enum { VMGLAnnotationTagNotFound = UINT32_MAX };

/// The threshold used to consider when a tilt gesture should start.
const CLLocationDegrees VMGLHorizontalTiltToleranceDegrees = 45.0;

/// The time between background snapshot attempts.
const NSTimeInterval VMGLBackgroundSnapshotImageInterval = 60.0;

/// The delay after the map has idled before a background snapshot is attempted.
const NSTimeInterval VMGLBackgroundSnapshotImageIdleDelay = 3.0;

/// Mapping from an annotation tag to metadata about that annotation, including
/// the annotation itself.
typedef std::unordered_map<VMGLAnnotationTag, VMGLAnnotationContext> VMGLAnnotationTagContextMap;

/// Mapping from an annotation object to an annotation tag.
typedef std::map<id<VMGLAnnotation>, VMGLAnnotationTag> VMGLAnnotationObjectTagMap;

mbgl::util::UnitBezier VMGLUnitBezierForMediaTimingFunction(CAMediaTimingFunction *function)
{
    if ( ! function)
    {
        function = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
    }
    float p1[2], p2[2];
    [function getControlPointAtIndex:0 values:p1];
    [function getControlPointAtIndex:1 values:p2];
    return { p1[0], p1[1], p2[0], p2[1] };
}

/// Lightweight container for metadata about an annotation, including the annotation itself.
class VMGLAnnotationContext {
public:
    id <VMGLAnnotation> annotation;
    /// The annotation’s image’s reuse identifier.
    NSString *imageReuseIdentifier;
    VMGLAnnotationAccessibilityElement *accessibilityElement;
    VMGLAnnotationView *annotationView;
    NSString *viewReuseIdentifier;
};

#pragma mark - Private -

@interface VMGLMapView () <UIGestureRecognizerDelegate,
                          VMGLLocationManagerDelegate,
                          VMGLSMCalloutViewDelegate,
                          VMGLCalloutViewDelegate,
                          VMGLMultiPointDelegate,
                          VMGLAnnotationImageDelegate>

@property (nonatomic) UIImageView *glSnapshotView;

@property (nonatomic) NSMutableArray<NSLayoutConstraint *> *scaleBarConstraints;
@property (nonatomic, readwrite) VMGLScaleBar *scaleBar;
@property (nonatomic, readwrite) VMGLCompassButton *compassView;
@property (nonatomic) NSMutableArray<NSLayoutConstraint *> *compassViewConstraints;
@property (nonatomic, readwrite) UIImageView *logoView;
@property (nonatomic) NSMutableArray<NSLayoutConstraint *> *logoViewConstraints;
@property (nonatomic, readwrite) UIButton *attributionButton;
@property (nonatomic) NSMutableArray<NSLayoutConstraint *> *attributionButtonConstraints;
@property (nonatomic, weak) UIAlertController *attributionController;

@property (nonatomic, readwrite) VMGLStyle *style;

@property (nonatomic) UITapGestureRecognizer *singleTapGestureRecognizer;
@property (nonatomic) UITapGestureRecognizer *doubleTap;
@property (nonatomic) UITapGestureRecognizer *twoFingerTap;
@property (nonatomic) UIPanGestureRecognizer *pan;
@property (nonatomic) UIPinchGestureRecognizer *pinch;
@property (nonatomic) UIRotationGestureRecognizer *rotate;
@property (nonatomic) UILongPressGestureRecognizer *quickZoom;
@property (nonatomic) UIPanGestureRecognizer *twoFingerDrag;

@property (nonatomic) UIInterfaceOrientation currentOrientation;
@property (nonatomic) UIInterfaceOrientationMask applicationSupportedInterfaceOrientations;

@property (nonatomic) VMGLCameraChangeReason cameraChangeReasonBitmask;

/// Mapping from reusable identifiers to annotation images.
@property (nonatomic) NSMutableDictionary<NSString *, VMGLAnnotationImage *> *annotationImagesByIdentifier;

/// Currently shown popover representing the selected annotation.
@property (nonatomic) UIView<VMGLCalloutView> *calloutViewForSelectedAnnotation;

/// Anchor coordinate from which to present callout views (for example, for shapes this
/// could be the touch point rather than its centroid)
@property (nonatomic) CLLocationCoordinate2D anchorCoordinateForSelectedAnnotation;

@property (nonatomic) VMGLUserLocationAnnotationView *userLocationAnnotationView;

/// Indicates how thoroughly the map view is tracking the user location.
@property (nonatomic) VMGLUserTrackingState userTrackingState;
@property (nonatomic) CGFloat scale;
@property (nonatomic) CGFloat angle;
@property (nonatomic) CGFloat quickZoomStart;
/// Dormant means there is no underlying GL view (typically in the background)
@property (nonatomic, getter=isDormant) BOOL dormant;
@property (nonatomic, readonly, getter=isDisplayLinkActive) BOOL displayLinkActive;
@property (nonatomic, readonly, getter=isRotationAllowed) BOOL rotationAllowed;
@property (nonatomic) CGFloat rotationThresholdWhileZooming;
@property (nonatomic) CGFloat rotationBeforeThresholdMet;
@property (nonatomic) BOOL isZooming;
@property (nonatomic) BOOL isRotating;
@property (nonatomic) BOOL shouldTriggerHapticFeedbackForCompass;
@property (nonatomic) VMGLMapViewProxyAccessibilityElement *mapViewProxyAccessibilityElement;
@property (nonatomic) VMGLAnnotationContainerView *annotationContainerView;
@property (nonatomic) VMGLUserLocation *userLocation;
@property (nonatomic) NSMutableDictionary<NSString *, NSMutableArray<VMGLAnnotationView *> *> *annotationViewReuseQueueByIdentifier;
@property (nonatomic, readonly) BOOL enablePresentsWithTransaction;
@property (nonatomic) UIImage *lastSnapshotImage;
@property (nonatomic) NSMutableArray *pendingCompletionBlocks;

/// Experimental rendering performance measurement.
@property (nonatomic) BOOL experimental_enableFrameRateMeasurement;
@property (nonatomic) CGFloat averageFrameRate;
@property (nonatomic) CFTimeInterval frameTime;
@property (nonatomic) CFTimeInterval averageFrameTime;

/// Residual properties (saved on app termination)
@property (nonatomic) BOOL terminated;
@property (nonatomic, copy) VMGLMapCamera *residualCamera;
@property (nonatomic) VMGLMapDebugMaskOptions residualDebugMask;
@property (nonatomic, copy) NSURL *residualStyleURL;

/// Tilt gesture recognizer helper
@property (nonatomic, assign) CGPoint dragGestureMiddlePoint;

/// This property is used to keep track of the view's safe edge insets
/// and calculate the ornament's position
@property (nonatomic, assign) UIEdgeInsets safeMapViewContentInsets;
@property (nonatomic, strong) NSNumber *automaticallyAdjustContentInsetHolder;

// Display Link
@property (nonatomic, weak) UIScreen *displayLinkScreen;
@property (nonatomic) CADisplayLink *displayLink;
@property (nonatomic, assign) BOOL needsDisplayRefresh;

@end

@implementation VMGLMapView
{
    std::unique_ptr<mbgl::Map> _mbglMap;
    std::unique_ptr<VMGLMapViewImpl> _mbglView;
    std::unique_ptr<VMGLRenderFrontend> _rendererFrontend;
    
    BOOL _opaque;

    VMGLAnnotationTagContextMap _annotationContextsByAnnotationTag;
    VMGLAnnotationObjectTagMap _annotationTagsByAnnotation;

    /// Tag of the selected annotation. If the user location annotation is selected, this ivar is set to `MGLAnnotationTagNotFound`.
    VMGLAnnotationTag _selectedAnnotationTag;

    BOOL _userLocationAnnotationIsSelected;
    /// Size of the rectangle formed by unioning the maximum slop area around every annotation image and annotation image view.
    CGSize _unionedAnnotationRepresentationSize;
    CGSize _largestAnnotationViewSize;
    std::vector<VMGLAnnotationTag> _annotationsNearbyLastTap;
    CGPoint _initialImplicitCalloutViewOffset;
    NSDate *_userLocationAnimationCompletionDate;
    /// True if a willChange notification has been issued for shape annotation layers and a didChange notification is pending.
    BOOL _isChangingAnnotationLayers;
    BOOL _isWaitingForRedundantReachableNotification;

    CLLocationDegrees _pendingLatitude;
    CLLocationDegrees _pendingLongitude;

    NSInteger _changeDelimiterSuppressionDepth;

    /// Center of the pinch gesture on the previous iteration of the gesture.
    CGPoint _previousPinchCenterPoint;
    NSUInteger _previousPinchNumberOfTouches;
    
    CLLocationDistance _distanceFromOldUserLocation;

    BOOL _delegateHasAlphasForShapeAnnotations;
    BOOL _delegateHasStrokeColorsForShapeAnnotations;
    BOOL _delegateHasFillColorsForShapeAnnotations;
    BOOL _delegateHasLineWidthsForShapeAnnotations;

    NSArray<id <VMGLFeature>> *_visiblePlaceFeatures;
    NSArray<id <VMGLFeature>> *_visibleRoadFeatures;
    NSMutableSet<VMGLFeatureAccessibilityElement *> *_featureAccessibilityElements;
    BOOL _accessibilityValueAnnouncementIsPending;

    VMGLReachability *_reachability;

    /// Experimental rendering performance measurement.
    CFTimeInterval _frameCounterStartTime;
    NSInteger _frameCount;
    CFTimeInterval _frameDurations;
}

#pragma mark - Setup & Teardown -

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        MGLLogInfo(@"Starting %@ initialization.", NSStringFromClass([self class]));
        MGLLogDebug(@"Initializing frame: %@", NSStringFromCGRect(frame));
        [self commonInit];
        self.styleURL = nil;
        MGLLogInfo(@"Finalizing %@ initialization.", NSStringFromClass([self class]));
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame styleURL:(nullable NSURL *)styleURL
{
    if (self = [super initWithFrame:frame])
    {
        MGLLogInfo(@"Starting %@ initialization.", NSStringFromClass([self class]));
        MGLLogDebug(@"Initializing frame: %@ styleURL: %@", NSStringFromCGRect(frame), styleURL);
        [self commonInit];
        self.styleURL = styleURL;
        MGLLogInfo(@"Finalizing %@ initialization.", NSStringFromClass([self class]));
    }
    return self;
}

- (instancetype)initWithCoder:(nonnull NSCoder *)decoder
{
    if (self = [super initWithCoder:decoder])
    {
        MGLLogInfo(@"Starting %@ initialization.", NSStringFromClass([self class]));
        [self commonInit];
        self.styleURL = nil;
        MGLLogInfo(@"Finalizing %@ initialization.", NSStringFromClass([self class]));
    }
    return self;
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingStyle
{
    return [NSSet setWithObject:@"styleURL"];
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingStyleURL
{
    return [NSSet setWithObjects:@"styleURL__", nil];
}

- (nonnull NSURL *)styleURL
{
    if (!_mbglMap)
    {
        NSAssert(self.terminated, @"_mbglMap should only be unavailable during app termination");
        return self.residualStyleURL;
    }

    NSString *styleURLString = @(self.vmglMap.getStyle().getURL().c_str()).mgl_stringOrNilIfEmpty;
    MGLAssert(styleURLString, @"Invalid style URL string %@", styleURLString);
    return styleURLString ? [NSURL URLWithString:styleURLString] : nil;
}

- (void)setStyleURL:(nullable NSURL *)styleURL
{
    if ( ! styleURL)
    {
        styleURL = [VMGLStyle defaultStyleURL];
    }
    MGLLogDebug(@"Setting styleURL: %@", styleURL);
    styleURL = styleURL.mgl_URLByStandardizingScheme;
    self.style = nil;
    self.vmglMap.getStyle().loadURL([[styleURL absoluteString] UTF8String]);
}

- (IBAction)reloadStyle:(__unused id)sender {
    MGLLogInfo(@"Reloading style.");
    NSURL *styleURL = self.styleURL;
    self.vmglMap.getStyle().loadURL("");
    self.styleURL = styleURL;
}

- (mbgl::Map &)vmglMap
{
    if (!_mbglMap)
    {
        [NSException raise:VMGLUnderlyingMapUnavailableException
                    format:@"The underlying map is not available - this happens during app termination"];
    }
    return *_mbglMap;
}

- (mbgl::Renderer *)renderer
{
    return _rendererFrontend->getRenderer();
}

- (void)commonInit
{
    _opaque = NO;

    // setup accessibility
//  self.isAccessibilityElement = YES;

    // Ensure network configuration is set up (connect gl-native networking to
    // platform SDK via delegation). Calling `resetNativeNetworkManagerDelegate`
    // is not necessary here, since the shared manager already calls it.
    [VMGLNetworkConfiguration sharedManager];

    self.accessibilityLabel = NSLocalizedStringWithDefaultValue(@"MAP_A11Y_LABEL", nil, nil, @"Map", @"Accessibility label");
    self.accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction | UIAccessibilityTraitAdjustable;
    self.backgroundColor = [UIColor clearColor];
    self.clipsToBounds = YES;
    if (@available(iOS 11.0, *)) { self.accessibilityIgnoresInvertColors = YES; }

    self.preferredFramesPerSecond = VMGLMapViewPreferredFramesPerSecondDefault;

    // setup mbgl view
    _mbglView = VMGLMapViewImpl::Create(self);
    
    BOOL background = [UIApplication sharedApplication].applicationState == UIApplicationStateBackground;
    if (!background)
    {
        _mbglView->createView();
    }
    // Delete the pre-offline ambient cache at ~/Library/Caches/cache.db.
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *fileCachePath = [paths.firstObject stringByAppendingPathComponent:@"cache.db"];
    [[NSFileManager defaultManager] removeItemAtPath:fileCachePath error:NULL];

    // setup mbgl map
    VMGLRendererConfiguration *config = [VMGLRendererConfiguration currentConfiguration];

    mbgl::optional<std::string> localFontFamilyName = config.localFontFamilyName ? mbgl::optional<std::string>(std::string(config.localFontFamilyName.UTF8String)) : mbgl::nullopt;
    auto renderer = std::make_unique<mbgl::Renderer>(_mbglView->getRendererBackend(), config.scaleFactor, localFontFamilyName);
    BOOL enableCrossSourceCollisions = !config.perSourceCollisions;
    _rendererFrontend = std::make_unique<VMGLRenderFrontend>(std::move(renderer), self, _mbglView->getRendererBackend());

    mbgl::MapOptions mapOptions;
    mapOptions.withMapMode(mbgl::MapMode::Continuous)
              .withSize(self.size)
              .withPixelRatio(config.scaleFactor)
              .withConstrainMode(mbgl::ConstrainMode::None)
              .withViewportMode(mbgl::ViewportMode::Default)
              .withCrossSourceCollisions(enableCrossSourceCollisions);


    mbgl::TileServerOptions* tileServerOptions = [[VMGLSettings sharedSettings] tileServerOptionsInternal];
    mbgl::ResourceOptions resourceOptions;
    resourceOptions.withCachePath(VMGLOfflineStorage.sharedOfflineStorage.databasePath.UTF8String)
                   .withAssetPath([NSBundle mainBundle].resourceURL.path.UTF8String)
                   .withTileServerOptions(*tileServerOptions);
    mbgl::ClientOptions clientOptions;

    auto apiKey = [[VMGLSettings sharedSettings] apiKey];
    if (apiKey) {
        resourceOptions.withApiKey([apiKey UTF8String]);
    }

    NSAssert(!_mbglMap, @"_mbglMap should be NULL");
    _mbglMap = std::make_unique<mbgl::Map>(*_rendererFrontend, *_mbglView, mapOptions, resourceOptions, clientOptions);

    // start paused if launch into the background
    if (background) {
        self.dormant = YES;
    }

    // Notify map object when network reachability status changes.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kMGLReachabilityChangedNotification
                                               object:nil];

    _reachability = [VMGLReachability reachabilityForInternetConnection];
    if ([_reachability isReachable])
    {
        _isWaitingForRedundantReachableNotification = YES;
    }
    [_reachability startNotifier];
    
    // setup default location manager
    self.locationManager = nil;

    // Set up annotation management and selection state.
    _annotationImagesByIdentifier = [NSMutableDictionary dictionary];
    _annotationContextsByAnnotationTag = {};
    _annotationTagsByAnnotation = {};
    _annotationViewReuseQueueByIdentifier = [NSMutableDictionary dictionary];
    _selectedAnnotationTag = VMGLAnnotationTagNotFound;
    _annotationsNearbyLastTap = {};

    // TODO: This warning should be removed when automaticallyAdjustsScrollViewInsets is removed from
    // the UIViewController api.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"%@ WARNING UIViewController.automaticallyAdjustsScrollViewInsets is deprecated use MGLMapView.automaticallyAdjustContentInset instead.",
        NSStringFromClass(self.class));
    });

    // setup logo
    //
    UIImage *logo = [UIImage mgl_resourceImageNamed:@"mapbox"];
    _logoView = [[UIImageView alloc] initWithImage:logo];
    _logoView.accessibilityTraits = UIAccessibilityTraitStaticText;
    _logoView.accessibilityLabel = NSLocalizedStringWithDefaultValue(@"LOGO_A11Y_LABEL", nil, nil, @"Mapbox", @"Accessibility label");
    _logoView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_logoView];
    _logoViewConstraints = [NSMutableArray array];
    _logoViewPosition = VMGLOrnamentPositionBottomLeft;
    _logoViewMargins = VMGLOrnamentDefaultPositionOffset;

    // setup attribution
    //
    _attributionButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    _attributionButton.accessibilityLabel = NSLocalizedStringWithDefaultValue(@"INFO_A11Y_LABEL", nil, nil, @"About this map", @"Accessibility label");
    _attributionButton.accessibilityHint = NSLocalizedStringWithDefaultValue(@"INFO_A11Y_HINT", nil, nil, @"Shows credits, a feedback form, and more", @"Accessibility hint");
    [_attributionButton addTarget:self action:@selector(showAttribution:) forControlEvents:UIControlEventTouchUpInside];
    _attributionButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_attributionButton];
    _attributionButtonConstraints = [NSMutableArray array];

    UILongPressGestureRecognizer *attributionLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(showAttribution:)];
    [_attributionButton addGestureRecognizer:attributionLongPress];
    _attributionButtonPosition = VMGLOrnamentPositionBottomRight;
    _attributionButtonMargins = VMGLOrnamentDefaultPositionOffset;

    // setup compass
    //
    _compassView = [VMGLCompassButton compassButtonWithMapView:self];
    [self addSubview:_compassView];
    _compassViewConstraints = [NSMutableArray array];
    _compassViewPosition = VMGLOrnamentPositionTopRight;
    _compassViewMargins = VMGLOrnamentDefaultPositionOffset;
    
    // setup scale control
    //
    _scaleBar = [[VMGLScaleBar alloc] init];
    _scaleBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_scaleBar];
    _scaleBarConstraints = [NSMutableArray array];
    _scaleBarPosition = VMGLOrnamentPositionTopLeft;
    _scaleBarMargins = VMGLOrnamentDefaultPositionOffset;

    [self installConstraints];

    // setup interaction
    //
    
    self.anchorRotateOrZoomGesturesToCenterCoordinate = NO;
    
    _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    _pan.delegate = self;
    _pan.maximumNumberOfTouches = 1;
    [self addGestureRecognizer:_pan];
    _scrollEnabled = YES;
    _panScrollingMode = VMGLPanScrollingModeDefault;

    _pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
    _pinch.delegate = self;
    [self addGestureRecognizer:_pinch];
    _zoomEnabled = YES;

    _rotate = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(handleRotateGesture:)];
    _rotate.delegate = self;
    [self addGestureRecognizer:_rotate];
    _rotateEnabled = YES;
    _rotationThresholdWhileZooming = 3;

    _doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTapGesture:)];
    _doubleTap.numberOfTapsRequired = 2;
    [self addGestureRecognizer:_doubleTap];

    _twoFingerDrag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleTwoFingerDragGesture:)];
    _twoFingerDrag.minimumNumberOfTouches = 2;
    _twoFingerDrag.maximumNumberOfTouches = 2;
    _twoFingerDrag.delegate = self;
    [_twoFingerDrag requireGestureRecognizerToFail:_pan];
    [self addGestureRecognizer:_twoFingerDrag];
    _pitchEnabled = YES;

    _twoFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTwoFingerTapGesture:)];
    _twoFingerTap.numberOfTouchesRequired = 2;
    [_twoFingerTap requireGestureRecognizerToFail:_pinch];
    [_twoFingerTap requireGestureRecognizerToFail:_rotate];
    [_twoFingerTap requireGestureRecognizerToFail:_twoFingerDrag];
    [self addGestureRecognizer:_twoFingerTap];

    _hapticFeedbackEnabled = YES;

    _decelerationRate = VMGLMapViewDecelerationRateNormal;

    _quickZoom = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleQuickZoomGesture:)];
    _quickZoom.numberOfTapsRequired = 1;
    _quickZoom.minimumPressDuration = 0;
    [_quickZoom requireGestureRecognizerToFail:_doubleTap];
    [self addGestureRecognizer:_quickZoom];

    _singleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTapGesture:)];
    [_singleTapGestureRecognizer requireGestureRecognizerToFail:_doubleTap];
    _singleTapGestureRecognizer.delegate = self;
    [_singleTapGestureRecognizer requireGestureRecognizerToFail:_quickZoom];
    [self addGestureRecognizer:_singleTapGestureRecognizer];

    // observe app activity
    //
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willTerminate) name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];

    // Pending completion blocks are called *after* annotation views have been updated
    // in updateFromDisplayLink.
    _pendingCompletionBlocks = [NSMutableArray array];
    
    
    // As of 3.7.5, we intentionally do not listen for `UIApplicationWillResignActiveNotification` or call `pauseRendering:` in response to it, as doing
    // so causes a loop when asking for location permission. See: https://github.com/mapbox/mapbox-gl-native/issues/11225

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];

    // Device orientation management
    self.currentOrientation = UIInterfaceOrientationUnknown;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

    // set initial position
    //
    mbgl::CameraOptions options;
    options.center = mbgl::LatLng(0, 0);
    mbgl::EdgeInsets padding = VMGLEdgeInsetsFromNSEdgeInsets(self.contentInset);
    options.padding = padding;
    options.zoom = 0;

    _cameraChangeReasonBitmask = VMGLCameraChangeReasonNone;

    _mbglMap->jumpTo(options);
    _pendingLatitude = NAN;
    _pendingLongitude = NAN;
    _targetCoordinate = kCLLocationCoordinate2DInvalid;
}

- (mbgl::Size)size
{
    // check for minimum texture size supported by OpenGL ES 2.0
    //
    CGSize size = CGSizeMake(MAX(self.bounds.size.width, 64), MAX(self.bounds.size.height, 64));
    return { static_cast<uint32_t>(size.width),
             static_cast<uint32_t>(size.height) };
}

- (void)reachabilityChanged:(NSNotification *)notification
{
    MGLAssertIsMainThread();

    VMGLReachability *reachability = [notification object];
    if ( ! _isWaitingForRedundantReachableNotification && [reachability isReachable])
    {
        mbgl::NetworkStatus::Reachable();
    }
    _isWaitingForRedundantReachableNotification = NO;
}


- (void)destroyCoreObjects {
    // Record the current state. Currently only saving a limited set of properties.
    self.terminated = YES;
    self.residualCamera = self.camera;
    self.residualDebugMask = self.debugMask;
    self.residualStyleURL = self.styleURL;
    
    // Tear down C++ objects, insuring worker threads correctly terminate.
    // Because of how _mbglMap is constructed, we need to destroy it first.
    _mbglMap.reset();

    _mbglView.reset();

    _rendererFrontend.reset();
}

- (void)dealloc
{
    MGLLogInfo(@"Deallocating MGLMapView.");
    [_reachability stopNotifier];

    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // Removing the annotations unregisters any outstanding KVO observers.
    NSArray *annotations = self.annotations;
    if (annotations)
    {
        [self removeAnnotations:annotations];
    }

    [self destroyDisplayLink];

    [self destroyCoreObjects];

    [self.compassViewConstraints removeAllObjects];
    self.compassViewConstraints = nil;
    
    [self.scaleBarConstraints removeAllObjects];
    self.scaleBarConstraints = nil;
    
    [self.logoViewConstraints removeAllObjects];
    self.logoViewConstraints = nil;
    
    [self.attributionButtonConstraints removeAllObjects];
    self.attributionButtonConstraints = nil;
    
    [_locationManager stopUpdatingLocation];
    [_locationManager stopUpdatingHeading];
    _locationManager.delegate = nil;
}

- (void)setDelegate:(nullable id<VMGLMapViewDelegate>)delegate
{
    MGLLogDebug(@"Setting delegate: %@", delegate);
    if (_delegate == delegate) return;

    _delegate = delegate;

    _delegateHasAlphasForShapeAnnotations = [_delegate respondsToSelector:@selector(mapView:alphaForShapeAnnotation:)];
    _delegateHasStrokeColorsForShapeAnnotations = [_delegate respondsToSelector:@selector(mapView:strokeColorForShapeAnnotation:)];
    _delegateHasFillColorsForShapeAnnotations = [_delegate respondsToSelector:@selector(mapView:fillColorForPolygonAnnotation:)];
    _delegateHasLineWidthsForShapeAnnotations = [_delegate respondsToSelector:@selector(mapView:lineWidthForPolylineAnnotation:)];
}

- (void)didReceiveMemoryWarning
{
    MGLAssertIsMainThread();

    if ( ! self.dormant && _rendererFrontend)
    {
        _rendererFrontend->reduceMemoryUse();
    }
    
    self.lastSnapshotImage = nil;
}

- (VMGLMapViewImpl *)viewImpl
{
    return _mbglView.get();
}

#pragma mark - Layout -

+ (BOOL)requiresConstraintBasedLayout
{
    return YES;
}

- (void)setScaleBarPosition:(VMGLOrnamentPosition)scaleBarPosition {
    MGLLogDebug(@"Setting scaleBarPosition: %lu", scaleBarPosition);
    _scaleBarPosition = scaleBarPosition;
    [self installScaleBarConstraints];
}

- (void)setScaleBarMargins:(CGPoint)scaleBarMargins {
    MGLLogDebug(@"Setting scaleBarMargins: (x:%f, y:%f)", scaleBarMargins.x, scaleBarMargins.y);
    _scaleBarMargins = scaleBarMargins;
    [self installScaleBarConstraints];
}

- (void)setCompassViewPosition:(VMGLOrnamentPosition)compassViewPosition {
    MGLLogDebug(@"Setting compassViewPosition: %lu", compassViewPosition);
    _compassViewPosition = compassViewPosition;
    [self installCompassViewConstraints];
}

- (void)setCompassViewMargins:(CGPoint)compassViewMargins {
    MGLLogDebug(@"Setting compassViewOffset: (x:%f, y:%f)", compassViewMargins.x, compassViewMargins.y);
    _compassViewMargins = compassViewMargins;
    [self installCompassViewConstraints];
}

- (void)setLogoViewPosition:(VMGLOrnamentPosition)logoViewPosition {
    MGLLogDebug(@"Setting logoViewPosition: %lu", logoViewPosition);
    _logoViewPosition = logoViewPosition;
    [self installLogoViewConstraints];
}

- (void)setLogoViewMargins:(CGPoint)logoViewMargins {
    MGLLogDebug(@"Setting logoViewMargins: (x:%f, y:%f)", logoViewMargins.x, logoViewMargins.y);
    _logoViewMargins = logoViewMargins;
    [self installLogoViewConstraints];
}

- (void)setAttributionButtonPosition:(VMGLOrnamentPosition)attributionButtonPosition {
    MGLLogDebug(@"Setting attributionButtonPosition: %lu", attributionButtonPosition);
    _attributionButtonPosition = attributionButtonPosition;
    [self installAttributionButtonConstraints];
}

- (void)setAttributionButtonMargins:(CGPoint)attributionButtonMargins {
    MGLLogDebug(@"Setting attributionButtonMargins: (x:%f, y:%f)", attributionButtonMargins.x, attributionButtonMargins.y);
    _attributionButtonMargins = attributionButtonMargins;
    [self installAttributionButtonConstraints];
}

- (void)updateConstraintsForOrnament:(UIView *)view
                         constraints:(NSMutableArray *)constraints
                            position:(VMGLOrnamentPosition)position
                                size:(CGSize)size
                             margins:(CGPoint)margins {
    NSMutableArray *updatedConstraints = [NSMutableArray array];
    UIEdgeInsets inset = UIEdgeInsetsZero;
    
    BOOL automaticallyAdjustContentInset;
    if (_automaticallyAdjustContentInsetHolder) {
        automaticallyAdjustContentInset = _automaticallyAdjustContentInsetHolder.boolValue;
    } else {
        UIViewController *viewController = [self rootViewController];
        automaticallyAdjustContentInset = viewController.automaticallyAdjustsScrollViewInsets;
    }
    
    if (! automaticallyAdjustContentInset) {
        inset = UIEdgeInsetsMake(self.contentInset.top - self.safeMapViewContentInsets.top,
                                 self.contentInset.left - self.safeMapViewContentInsets.left,
                                 self.contentInset.bottom - self.safeMapViewContentInsets.bottom,
                                 self.contentInset.right - self.safeMapViewContentInsets.right);
        
        // makes sure the insets don't have negative values that could hide the ornaments
        // thus violating our ToS
        inset = UIEdgeInsetsMake(fmaxf(inset.top, 0),
                                 fmaxf(inset.left, 0),
                                 fmaxf(inset.bottom, 0),
                                 fmaxf(inset.right, 0));
    }
    
    switch (position) {
        case VMGLOrnamentPositionTopLeft:
            [updatedConstraints addObject:[view.topAnchor constraintEqualToAnchor:self.mgl_safeTopAnchor constant:margins.y + inset.top]];
            [updatedConstraints addObject:[view.leadingAnchor constraintEqualToAnchor:self.mgl_safeLeadingAnchor constant:margins.x + inset.left]];
            break;
        case VMGLOrnamentPositionTopRight:
            [updatedConstraints addObject:[view.topAnchor constraintEqualToAnchor:self.mgl_safeTopAnchor constant:margins.y + inset.top]];
            [updatedConstraints addObject:[self.mgl_safeTrailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:margins.x + inset.right]];
            break;
        case VMGLOrnamentPositionBottomLeft:
            [updatedConstraints addObject:[self.mgl_safeBottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:margins.y + inset.bottom]];
            [updatedConstraints addObject:[view.leadingAnchor constraintEqualToAnchor:self.mgl_safeLeadingAnchor constant:margins.x + inset.left]];
            break;
        case VMGLOrnamentPositionBottomRight:
            [updatedConstraints addObject:[self.mgl_safeBottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:margins.y + inset.bottom]];
            [updatedConstraints addObject: [self.mgl_safeTrailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:margins.x + inset.right]];
            break;
    }

    if (!CGSizeEqualToSize(size, CGSizeZero)) {
        NSLayoutConstraint *widthConstraint = [view.widthAnchor constraintEqualToConstant:size.width];
        widthConstraint.identifier = @"width";
        NSLayoutConstraint *heightConstraint = [view.heightAnchor constraintEqualToConstant:size.height];
        heightConstraint.identifier = @"height";
        [updatedConstraints addObjectsFromArray:@[widthConstraint,heightConstraint]];
    }
    
    [NSLayoutConstraint deactivateConstraints:constraints];
    [constraints removeAllObjects];
    [NSLayoutConstraint activateConstraints:updatedConstraints];
    [constraints addObjectsFromArray:updatedConstraints];
}

- (void)installConstraints
{
    [self installCompassViewConstraints];
    [self installScaleBarConstraints];
    [self installLogoViewConstraints];
    [self installAttributionButtonConstraints];
}

- (void)installCompassViewConstraints {
    // compass view
    [self updateConstraintsForOrnament:self.compassView
                           constraints:self.compassViewConstraints
                              position:self.compassViewPosition
                                  size:[self sizeForOrnament:self.compassView constraints:self.compassViewConstraints]
                               margins:self.compassViewMargins];
}

- (void)installScaleBarConstraints {
    // scale bar view
    [self updateConstraintsForOrnament:self.scaleBar
                           constraints:self.scaleBarConstraints
                              position:self.scaleBarPosition
                                  size:CGSizeZero
                               margins:self.scaleBarMargins];
}

- (void)installLogoViewConstraints {
    // logo view
    [self updateConstraintsForOrnament:self.logoView
                           constraints:self.logoViewConstraints
                              position:self.logoViewPosition
                                  size:[self sizeForOrnament:self.logoView constraints:self.logoViewConstraints]
                               margins:self.logoViewMargins];
}

- (void)installAttributionButtonConstraints {
    // attribution button
    [self updateConstraintsForOrnament:self.attributionButton
                           constraints:self.attributionButtonConstraints
                              position:self.attributionButtonPosition
                                  size:[self sizeForOrnament:self.attributionButton constraints:self.attributionButtonConstraints]
                               margins:self.attributionButtonMargins];
}

- (CGSize)sizeForOrnament:(UIView *)view
              constraints:(NSMutableArray *)constraints {
    // avoid regenerating size constraints
    CGSize size;
    if(constraints && constraints.count > 0) {
        for (NSLayoutConstraint * constraint in constraints) {
            if([constraint.identifier isEqualToString:@"width"]) {
                size.width = constraint.constant;
            }
            else if ([constraint.identifier isEqualToString:@"height"]) {
                size.height = constraint.constant;
            }
        }
    }
    else {
        size = view.bounds.size;
    }
    
    return size;
}

- (BOOL)isOpaque
{
    return _opaque;
}

- (void)setOpaque:(BOOL)opaque
{
    _opaque = opaque;
    if (_mbglView) {
        _mbglView->setOpaque(opaque);
    }
}

- (void)updateViewsWithCurrentUpdateParameters {
    // Update UIKit elements, prior to rendering
    [self updateUserLocationAnnotationView];
    [self updateAnnotationViews];
    [self updateCalloutView];
}

- (BOOL)renderSync
{
    BOOL hasPendingBlocks = (self.pendingCompletionBlocks.count > 0);

    if (!self.needsDisplayRefresh && !hasPendingBlocks) {
        return NO;
    }

    BOOL needsRender = self.needsDisplayRefresh;

    self.needsDisplayRefresh = NO;

    if (!self.dormant && needsRender)
    {
        // It's important to call this *before* `_rendererFrontend->render()`, as
        // that function saves the current `updateParameters` before rendering. If this
        // occurs after then the views will be a frame behind.
        //
        // The update parameters will have been updated earlier, for example by
        // calls to easeTo, flyTo, called from gesture handlers.
        
        [self updateViewsWithCurrentUpdateParameters];
      
        if (_rendererFrontend) {
            
            _rendererFrontend->render();

        }
        
    }

    if (hasPendingBlocks) {
        // Call any pending completion blocks. This is primarily to ensure
        // that annotations are in the expected position after core rendering
        // and map update.
        //
        // TODO: Consider using this same mechanism for delegate callbacks.
        [self processPendingBlocks];
    }

    return YES;
}

// This gets called when the view dimension changes, e.g. because the device is being rotated.
- (void)layoutSubviews
{
    [super layoutSubviews];

    // Calling this here instead of in the scale bar itself because if this is done in the
    // scale bar instance, it triggers a call to this `layoutSubviews` method that calls
    // `_mbglMap->setSize()` just below that triggers rendering update which triggers
    // another scale bar update which causes a rendering update loop and a major performace
    // degradation.
    [self.scaleBar invalidateIntrinsicContentSize];

    [self adjustContentInset];

    if (_mbglView) {
        _mbglView->layoutChanged();
    }

    if (_mbglMap) {
        self.vmglMap.setSize([self size]);
    }

    if (self.compassView.alpha)
    {
        [self updateCompass];
    }

    if (self.compassView.alpha || self.showsUserHeadingIndicator)
    {
        [self updateHeadingForDeviceOrientation];
    }

    [self updateUserLocationAnnotationView];

    [self updateAttributionAlertView];

    MGLAssert(self.attributionButton.isHidden || CGRectContainsRect(self.bounds, self.attributionButton.mgl_frameForIdentifyTransform),
              @"The attribution is not in the visible area of the mapview. Please check your position and offset settings");
    MGLAssert(self.scaleBar.isHidden || CGRectContainsRect(self.bounds, self.scaleBar.mgl_frameForIdentifyTransform),
              @"The scaleBar is not in the visible area of the mapview. Please check your position and offset settings");
    MGLAssert(self.compassView.isHidden || self.compassView.compassVisibility == MGLOrnamentVisibilityHidden || CGRectContainsRect(self.bounds, self.compassView.mgl_frameForIdentifyTransform),
              @"The compassView is not in the visible area of the mapview. Please check your position and offset settings");
    MGLAssert(self.logoView.isHidden || CGRectContainsRect(self.bounds, self.logoView.mgl_frameForIdentifyTransform),
              @"The logoView is not in the visible area of the mapview. Please check your position and offset settings");
}

/// Updates `contentInset` to reflect the current window geometry.
- (void)adjustContentInset
{
    UIEdgeInsets adjustedContentInsets = UIEdgeInsetsZero;
    UIViewController *viewController = [self rootViewController];
    BOOL automaticallyAdjustContentInset;
    if (@available(iOS 11.0, *))
    {
        adjustedContentInsets = self.safeAreaInsets;
        
    } else {
        adjustedContentInsets.top = viewController.topLayoutGuide.length;
        CGFloat bottomPoint = CGRectGetMaxY(viewController.view.bounds) -
                                (CGRectGetMaxY(viewController.view.bounds)
                                - viewController.bottomLayoutGuide.length);
        adjustedContentInsets.bottom = bottomPoint;

    }
    
    if (_automaticallyAdjustContentInsetHolder) {
        automaticallyAdjustContentInset = _automaticallyAdjustContentInsetHolder.boolValue;
    } else {
        automaticallyAdjustContentInset = viewController.automaticallyAdjustsScrollViewInsets;
    }
    
    self.safeMapViewContentInsets = adjustedContentInsets;
    if ( ! automaticallyAdjustContentInset)
    {
        return;
    }
    
    self.contentInset = adjustedContentInsets;
}

- (UIViewController *)rootViewController {
    // We could crawl all the way up the responder chain using
    // -viewControllerForLayoutGuides, but an intervening view means that any
    // manual contentInset should not be overridden; something other than the
    // top and bottom bars may be influencing the manual inset.
    UIViewController *viewController;
    if ([self.nextResponder isKindOfClass:[UIViewController class]])
    {
        // This map view is the content view of a view controller.
        viewController = (UIViewController *)self.nextResponder;
    }
    else if ([self.superview.nextResponder isKindOfClass:[UIViewController class]])
    {
        // This map view is an immediate child of a view controller’s content view.
        viewController = (UIViewController *)self.superview.nextResponder;
    }
    return viewController;
}

- (void)setAutomaticallyAdjustsContentInset:(BOOL)automaticallyAdjustsContentInset {
    MGLLogDebug(@"Setting automaticallyAdjustsContentInset: %@", VMGLStringFromBOOL(automaticallyAdjustsContentInset));
    _automaticallyAdjustContentInsetHolder = [NSNumber numberWithBool:automaticallyAdjustsContentInset];
}

- (BOOL)automaticallyAdjustsContentInset {
    return _automaticallyAdjustContentInsetHolder.boolValue;
}

- (void)setContentInset:(UIEdgeInsets)contentInset
{
    [self setContentInset:contentInset animated:NO completionHandler:nil];
}

- (void)setContentInset:(UIEdgeInsets)contentInset animated:(BOOL)animated
{
    [self setContentInset:contentInset animated:animated completionHandler:nil];
}

- (void)setContentInset:(UIEdgeInsets)contentInset animated:(BOOL)animated completionHandler:(nullable void (^)(void))completion
{
    MGLLogDebug(@"Setting contentInset: %@ animated:", NSStringFromUIEdgeInsets(contentInset), VMGLStringFromBOOL(animated));
    if (UIEdgeInsetsEqualToEdgeInsets(contentInset, self.contentInset))
    {
        if (completion) {
            completion();
        }
        return;
    }

    if (self.userTrackingMode == VMGLUserTrackingModeNone)
    {
        // Don’t call -setCenterCoordinate:, which resets the user tracking mode.
        [self _setCenterCoordinate:self.centerCoordinate edgePadding:contentInset zoomLevel:self.zoomLevel direction:self.direction duration:animated ? VMGLAnimationDuration : 0 animationTimingFunction:nil completionHandler:completion];
        _contentInset = contentInset;
    }
    else
    {
        _contentInset = contentInset;
        [self didUpdateLocationWithUserTrackingAnimated:animated completionHandler:completion];
    }

    // Compass, logo and attribution button constraints needs to be updated.z
    [self installConstraints];
}

/// Returns the frame of inset content within the map view.
- (CGRect)contentFrame
{
    return UIEdgeInsetsInsetRect(self.bounds, self.contentInset);
}

/// Returns the center point of the inset content within the map view.
- (CGPoint)contentCenter
{
    CGRect contentFrame = self.contentFrame;
    return CGPointMake(CGRectGetMidX(contentFrame), CGRectGetMidY(contentFrame));
}

#pragma mark - Pending completion blocks

- (void)processPendingBlocks
{
    NSArray *blocks = self.pendingCompletionBlocks;
    self.pendingCompletionBlocks = [NSMutableArray array];

    for (dispatch_block_t block in blocks)
    {
        block();
    }
}

- (BOOL)scheduleTransitionCompletion:(dispatch_block_t)block
{
    // Only add a block if the display link (that calls processPendingBlocks) is
    // running, otherwise fall back to calling immediately.
    if (self.isDisplayLinkActive)
    {
        [self willChangeValueForKey:@"pendingCompletionBlocks"];
        [self.pendingCompletionBlocks addObject:block];
        [self didChangeValueForKey:@"pendingCompletionBlocks"];
        return YES;
    }
    
    return NO;
}

#pragma mark - Life Cycle -

- (void)updateFromDisplayLink:(CADisplayLink *)displayLink
{
    // CADisplayLink's call interval closely matches the that defined by,
    // preferredFramesPerSecond, however it is NOT called on the vsync and
    // can fire some time after the vsync, and the duration can often exceed
    // the expected period.
    //
    // The `timestamp` property should represent (or be very close to) the vsync,
    // so for any kind of frame rate measurement, it can be important to record
    // the time upon entry to this method.
    //
    // This start time, coupled with the `targetTimestamp` gives you a measure
    // of how long you have to do work before the next vsync.
    //
    // Note that CADisplayLink's duration property is interval between vsyncs at
    // the device's natural frequency (60, 120). Instead, for the duration of a
    // frame, use the two timestamps instead. This is especially important if
    // you have set preferredFramesPerSecond to something other than the default.
    //
    //                 │   remaining duration  ┃
    //                 │◀ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ▶┃
    //     ┌ ─ ─ ─ ─ ─ ┼───────────────────────╋───────────────────────────────────┳───────
    //                 │                       ┃                                   ┃
    //     │           │                       ┃                                   ┃
    //                 │                       ┃                                   ┃
    //     ▼           │                       ▼                                   ▼
    // timestamp       │                    target
    // (vsync?)        │                   timestamp
    //                 │
    //                 ▼
    //           display link
    //            start time

    MGLAssertIsMainThread();

    // Not "visible" - this isn't a full definition of visibility, but if
    // the map view doesn't have a window then it *cannot* be visible.
    if (!self.window) {
        return;
    }

    // Mismatched display link
    if (displayLink && displayLink != _displayLink) {
        return;
    }

    // Check to ensure rendering doesn't occur in the background
    if (([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) &&
        ![self supportsBackgroundRendering])
    {
        return;
    }
    
    if (self.needsDisplayRefresh || (self.pendingCompletionBlocks.count > 0))
    {
        // UIView update logic has moved into `renderSync` above, which now gets
        // triggered by a call to setNeedsDisplay.
        // See MGLMapViewOpenGLImpl::display() for more details
        _mbglView->display();
    }

    // TODO: Fix
    if (self.experimental_enableFrameRateMeasurement)
    {
        CFTimeInterval now = CACurrentMediaTime();

        self.frameTime = now - _displayLink.timestamp;
        _frameDurations += self.frameTime;

        _frameCount++;

        CFTimeInterval elapsed = now - _frameCounterStartTime;

        if (elapsed >= 1.0) {
            self.averageFrameRate = _frameCount / elapsed;
            self.averageFrameTime = (_frameDurations / _frameCount) * 1000;

            _frameCount = 0;
            _frameDurations = 0;
            _frameCounterStartTime = now;
        }
    }
}

- (void)setNeedsRerender
{
    MGLAssertIsMainThread();

    self.needsDisplayRefresh = YES;
}

- (void)willTerminate
{
    MGLAssertIsMainThread();

    if ( ! self.dormant)
    {
        [self.displayLink invalidate];
        self.displayLink = nil;

        self.dormant = YES;

        if (_rendererFrontend) {
            _rendererFrontend->reduceMemoryUse();
        }

        _mbglView->deleteView();
    }

    [self destroyCoreObjects];
}

- (UIScreen *)windowScreen {
    UIScreen *screen;

#ifdef SUPPORT_UIWINDOWSCENE
    if (@available(iOS 13.0, *)) {
        if (self.window.windowScene) {
            screen = self.window.windowScene.screen;
        }
    }
#endif

    // Fallback if there's no windowScene
    if (!screen) {
        screen = self.window.screen;
    }

    return screen;
}

- (BOOL)isVisible
{
    // "Visible" is not strictly true here - for example, the view hierarchy is not
    // currently observed (e.g. looking at a parent's or the window's hidden
    // status.
    // This does NOT take application state into account
    UIScreen *screen = [self windowScreen];
    return (!self.isHidden && screen);
}

- (void)validateDisplayLink
{
    BOOL isVisible = self.superview && self.window;
    if (isVisible && ! _displayLink)
    {
        if (_mbglMap && self.vmglMap.getMapOptions().constrainMode() == mbgl::ConstrainMode::None)
        {
            self.vmglMap.setConstrainMode(mbgl::ConstrainMode::HeightOnly);
        }

        _displayLink = [self.window.screen displayLinkWithTarget:self selector:@selector(updateFromDisplayLink:)];
        [self updateDisplayLinkPreferredFramesPerSecond];
        [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        self.needsDisplayRefresh = YES;
        [self updateFromDisplayLink:_displayLink];
    }
    else if ( ! isVisible && _displayLink)
    {
        [_displayLink invalidate];
        _displayLink = nil;
        [self processPendingBlocks];
    }
}

- (void)updateDisplayLinkPreferredFramesPerSecond
{
    if (!_displayLink)
    {
        return;
    }

    NSInteger newFrameRate;
    if (_preferredFramesPerSecond == VMGLMapViewPreferredFramesPerSecondDefault)
    {
        // On legacy devices that cannot maintain a reasonable frame rate, set
        // a lower limit to avoid jank.
        newFrameRate = UIDevice.currentDevice.mgl_isLegacyDevice ? VMGLMapViewPreferredFramesPerSecondLowPower : VMGLMapViewPreferredFramesPerSecondMaximum;
    }
    else
    {
        newFrameRate = _preferredFramesPerSecond;
    }

    if (@available(iOS 10.0, *))
    {
        _displayLink.preferredFramesPerSecond = newFrameRate;
    }
    else
    {
        // CADisplayLink.frameInterval does not support more than 60 FPS (and
        // no device that supports >60 FPS ever supported iOS 9).
        NSInteger maximumFrameRate = 60;

        // `0` is an alias for maximum frame rate.
        newFrameRate = newFrameRate ?: maximumFrameRate;

        _displayLink.preferredFramesPerSecond = maximumFrameRate / MIN(newFrameRate, maximumFrameRate);
    }
}

- (void)setPreferredFramesPerSecond:(VMGLMapViewPreferredFramesPerSecond)preferredFramesPerSecond
{
    MGLLogDebug(@"Setting preferredFramesPerSecond: %ld", preferredFramesPerSecond);
    if (_preferredFramesPerSecond == preferredFramesPerSecond)
    {
        return;
    }

    _preferredFramesPerSecond = preferredFramesPerSecond;
    [self updateDisplayLinkPreferredFramesPerSecond];
}

- (void)updatePresentsWithTransaction
{
    BOOL hasEnoughViewAnnotations = (self.annotationContainerView.annotationViews.count > VMGLPresentsWithTransactionAnnotationCount);
    BOOL hasAnAnchoredCallout = [self hasAnAnchoredAnnotationCalloutView];
    
    _enablePresentsWithTransaction = (hasEnoughViewAnnotations || hasAnAnchoredCallout);
    
    // If the map is visible, change the layer property too
    if (self.window) {
        _mbglView->setPresentsWithTransaction(_enablePresentsWithTransaction);
    }
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    [super willMoveToWindow:newWindow];
    [self refreshSupportedInterfaceOrientationsWithWindow:newWindow];
    
    if (!newWindow)
    {
        // See https://github.com/mapbox/mapbox-gl-native/issues/14232
        // In iOS 12.2, CAEAGLLayer.presentsWithTransaction can cause dramatic
        // slow down. The exact cause of this is unknown, but this work around
        // appears to lessen the effects.
        _mbglView->setPresentsWithTransaction(NO);
    }
    
    // Changing windows regardless of whether it's a new one, or the map is being
    // removed from the hierarchy
    [self destroyDisplayLink];

    if (self.window) {
#ifdef SUPPORT_UIWINDOWSCENE
        if (@available(iOS 13.0, *))
        {
            [self.window removeObserver:self forKeyPath:@"windowScene" context:windowScreenContext];
        }
        else
#endif
        {
            [self.window removeObserver:self forKeyPath:@"screen" context:windowScreenContext];
        }
    }
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    MGLLogDebug(@"[%p] window=%p", self, self.window);

    if (self.window)
    {
        // See above comment
        [self resumeRenderingIfNecessary];
        [self updatePresentsWithTransaction];

#ifdef SUPPORT_UIWINDOWSCENE
        if (@available(iOS 13.0, *))
        {
            [self.window addObserver:self forKeyPath:@"windowScene" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:windowScreenContext];
        }
        else
#endif
        {
            [self.window addObserver:self forKeyPath:@"screen" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:windowScreenContext];
        }
    }
}

- (void)didMoveToSuperview
{
    [self validateDisplayLink];
    if (self.superview)
    {
        [self installConstraints];
    }
    [super didMoveToSuperview];
}

- (void)refreshSupportedInterfaceOrientationsWithWindow:(UIWindow *)window {
    
    // "The system intersects the view controller's supported orientations with
    // the app's supported orientations (as determined by the Info.plist file or
    // the app delegate's application:supportedInterfaceOrientationsForWindow:
    // method) and the device's supported orientations to determine whether to rotate.
    
    UIApplication *application = [UIApplication sharedApplication];
    
    if (window && [application.delegate respondsToSelector:@selector(application:supportedInterfaceOrientationsForWindow:)]) {
        self.applicationSupportedInterfaceOrientations = [application.delegate application:application supportedInterfaceOrientationsForWindow:window];
        return;
    }
    
    // If no delegate method, check the application's plist.
    static UIInterfaceOrientationMask orientationMask = UIInterfaceOrientationMaskAll;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // No application delegate
        NSArray *orientations = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UISupportedInterfaceOrientations"];
        
        // Application's info plist provided supported orientations.
        if (orientations.count > 0) {
            orientationMask = 0;
            
            NSDictionary *lookup =
            @{
              @"UIInterfaceOrientationPortrait" : @(UIInterfaceOrientationMaskPortrait),
              @"UIInterfaceOrientationPortraitUpsideDown" : @(UIInterfaceOrientationMaskPortraitUpsideDown),
              @"UIInterfaceOrientationLandscapeLeft" : @(UIInterfaceOrientationMaskLandscapeLeft),
              @"UIInterfaceOrientationLandscapeRight" : @(UIInterfaceOrientationMaskLandscapeRight)
              };
            
            for (NSString *orientation in orientations) {
                UIInterfaceOrientationMask mask = ((NSNumber*)lookup[orientation]).unsignedIntegerValue;
                orientationMask |= mask;
            }
        }
    });

    self.applicationSupportedInterfaceOrientations = orientationMask;
}

- (void)deviceOrientationDidChange:(__unused NSNotification *)notification
{
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    
    // The docs for `UIViewController.supportedInterfaceOrientations` states:
    //
    //  When the user changes the device orientation, the system calls this method
    //  on the root view controller or the topmost presented view controller that
    //  fills the window. If the view controller supports the new orientation, the
    //  window and view controller are rotated to the new orientation. This method
    //  is only called if the view controller's shouldAutorotate method returns YES.
    //
    // We want to match similar behaviour. However, it may be preferable to look
    // at the owning view controller (in cases where the map view may be covered
    // by another view.
    
    UIViewController *viewController = [self.window.rootViewController mgl_topMostViewController];
    
    if (![viewController shouldAutorotate]) {
        return;
    }
    
    if ((self.currentOrientation == (UIInterfaceOrientation)deviceOrientation) &&
        (self.currentOrientation != UIInterfaceOrientationUnknown)) {
        return;
    }
    
    // "The system intersects the view controller's supported orientations with
    // the app's supported orientations (as determined by the Info.plist file or
    // the app delegate's application:supportedInterfaceOrientationsForWindow:
    // method) and the device's supported orientations to determine whether to rotate.
    
    UIInterfaceOrientationMask supportedOrientations = viewController.supportedInterfaceOrientations;
    supportedOrientations &= self.applicationSupportedInterfaceOrientations;
    
    // Interface orientations are defined by device orientations
    UIInterfaceOrientationMask interfaceOrientation = 1 << deviceOrientation;
    UIInterfaceOrientationMask validOrientation = interfaceOrientation & UIInterfaceOrientationMaskAll;
    
    if (!(validOrientation & supportedOrientations)) {
        return;
    }
    
    self.currentOrientation = (UIInterfaceOrientation)deviceOrientation;

    // Q. Do we need to re-layout if we're just going from Portrait -> Portrait
    // Upside Down (or from Left to Right)?
    [self setNeedsLayout];
}

- (void)stopDisplayLink
{
    MGLLogDebug(@"[%p]", self);
    self.displayLink.paused = YES;
    self.needsDisplayRefresh = NO;
    [self processPendingBlocks];
}

- (void)createDisplayLink
{
    MGLLogDebug(@"[%p]", self);

    // Create and start the display link in a *paused* state
    MGLAssert(!self.displayLinkScreen, @"");
    MGLAssert(!self.displayLink, @"");
    MGLAssert(self.window, @"");
    MGLAssert(self.window.screen, @"");

    self.displayLinkScreen  = self.window.screen;
    self.displayLink        = [self.window.screen displayLinkWithTarget:self selector:@selector(updateFromDisplayLink:)];
    self.displayLink.paused = YES;

    [self updateDisplayLinkPreferredFramesPerSecond];

    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];

    if (_mbglMap && self.vmglMap.getMapOptions().constrainMode() == mbgl::ConstrainMode::None)
    {
        self.vmglMap.setConstrainMode(mbgl::ConstrainMode::HeightOnly);
    }
}

- (void)destroyDisplayLink
{
    MGLLogDebug(@"[%p]", self);
    [self.displayLink invalidate];
    self.displayLink = nil;
    self.displayLinkScreen = nil;
    self.needsDisplayRefresh = NO;
    [self processPendingBlocks];
}

- (void)startDisplayLink
{
    MGLLogDebug(@"[%p]", self);
    MGLAssert(self.displayLink, @"");
    MGLAssert([self isVisible], @"Display link should only be started when allowed");

    self.displayLink.paused = NO;
    [self setNeedsRerender];
    [self updateFromDisplayLink:self.displayLink];
}

#pragma mark - Application lifecycle
- (void)willResignActive:(NSNotification *)notification
{
    MGLAssertIsMainThread();
    MGLLogDebug(@"[%p]", self);

    // Going from active to inactive states. This could be because a system dialog
    // has been displayed, control center, or the app is headed into the background

    if (self.supportsBackgroundRendering) {
        return;
    }

    // We want to pause the rendering
    [self stopDisplayLink];

    // For OpenGL this calls glFinish as recommended in
    // https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/OpenGLES_ProgrammingGuide/ImplementingaMultitasking-awareOpenGLESApplication/ImplementingaMultitasking-awareOpenGLESApplication.html#//apple_ref/doc/uid/TP40008793-CH5-SW1
    // reduceMemoryUse(), calls performCleanup(), which calls glFinish
    if (_rendererFrontend)
    {
        _rendererFrontend->reduceMemoryUse();
    }
}

- (void)didEnterBackground:(NSNotification *)notification
{
    MGLAssertIsMainThread();
    MGLAssert(!self.dormant, @"Should not be dormant heading into background");
    MGLLogDebug(@"[%p] dormant=%d", self, self.dormant);

    // See comment in `supportsBackgroundRendering` above.
    if (self.supportsBackgroundRendering) {
        return;
    }

    // We now want to stop rendering.
    // We want to pause the rendering
    [self stopDisplayLink];

    // For OpenGL this calls glFinish as recommended in
    // https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/OpenGLES_ProgrammingGuide/ImplementingaMultitasking-awareOpenGLESApplication/ImplementingaMultitasking-awareOpenGLESApplication.html#//apple_ref/doc/uid/TP40008793-CH5-SW1
    // reduceMemoryUse(), calls performCleanup(), which calls glFinish
    if (_rendererFrontend)
    {
        _rendererFrontend->reduceMemoryUse();
    }

    // We now completely remove the display link, and the renderable resource.
    // Although the method below is called `deleteView` this does NOT delete the
    // GLKView, instead releasing the memory hungry resources.
    [self destroyDisplayLink];
    [self processPendingBlocks];
    _mbglView->deleteView();

    self.dormant = YES;

    // We want to add a snapshot image over the top of the map view, so that
    // there are no glitches when the application comes back into the foreground

    [self enableSnapshotView];

    // Handle non-rendering issues.
    [self validateLocationServices];
}

- (void)willEnterForeground:(NSNotification *)notification
{
    MGLLogDebug(@"[%p] dormant=%d", self, self.dormant);

    // We're transitioning from Background to Inactive states

    if (self.supportsBackgroundRendering) {
        return;
    }

    // Reverse the process of going into the background
    _mbglView->createView();

    // A display link needs the window's screen, so create it if we can
    UIScreen *screen = [self windowScreen];

    if (screen) {
        [self createDisplayLink];

        // If we can render during the inactive state, start the display link now
        if (self.isVisible) {
            [self startDisplayLink];
        }
    }
    self.dormant = NO;
    // Note: We do not remove the snapshot view (if there is one) until we have become
    // active.
    [self validateLocationServices];
    
}

- (void)didBecomeActive:(NSNotification *)notification
{
    MGLLogDebug(@"[%p] DL.paused=<%p>.paused=%d", self, self.displayLink, self.displayLink.paused);

    // Most times, we should already have a display link created at this point,
    // which may or may not be running. However, at the start of the application,
    // it's possible to have a situation where the display link hasn't been created.
    [self resumeRenderingIfNecessary];
}

#pragma mark - GL / display link wake/sleep

- (EAGLContext *)context {
    return _mbglView->getEAGLContext();
}

- (BOOL)supportsBackgroundRendering
{
    // Note: The following comment may be out of date with Metal enabled builds where
    // OpenGL is being emulated with Metal.
    //
    // If this view targets an external display, such as AirPlay or CarPlay, we
    // can safely continue to render OpenGL content without tripping
    // gpus_ReturnNotPermittedKillClient in libGPUSupportMercury, because the
    // external connection keeps the application from truly receding to the
    // background.
    UIScreen *screen = [self windowScreen];

    BOOL supportsBackgroundRendering =  (screen && (screen != [UIScreen mainScreen]));
    MGLLogDebug(@"supportsBackgroundRendering=%d",supportsBackgroundRendering);
    return supportsBackgroundRendering;
}

- (void)enableSnapshotView {
    if (self.lastSnapshotImage)
    {
        if ( ! self.glSnapshotView)
        {
            self.glSnapshotView = [[UIImageView alloc] initWithFrame: _mbglView->getView().frame];
            self.glSnapshotView.autoresizingMask = _mbglView->getView().autoresizingMask;
            self.glSnapshotView.contentMode = UIViewContentModeCenter;
            [self insertSubview:self.glSnapshotView aboveSubview:_mbglView->getView()];
        }

        self.glSnapshotView.image = self.lastSnapshotImage;
        self.glSnapshotView.hidden = NO;
        self.glSnapshotView.opaque = NO;
        self.glSnapshotView.alpha = 1;

        if (self.debugMask && [self.glSnapshotView.subviews count] == 0)
        {
            UIView *snapshotTint = [[UIView alloc] initWithFrame:self.glSnapshotView.bounds];
            snapshotTint.autoresizingMask = self.glSnapshotView.autoresizingMask;
            snapshotTint.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.25];
            [self.glSnapshotView addSubview:snapshotTint];
        }
    }
}

- (void)resumeRenderingIfNecessary {
    MGLLogDebug(@"[%p] DL.paused=<%p>.paused=%d", self, self.displayLink, self.displayLink.paused);

    // Most times, we should already have a display link created at this point,
    // which may or may not be running. However, at the start of the application,
    // it's possible to have a situation where the display link hasn't been created.

    // Reverse the process of going into the background
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground) {
        if (self.dormant) {
            _mbglView->createView();
            self.dormant = NO;
        }

        // Check display link, if necessary
        if (!self.displayLink) {
            if ([self windowScreen]) {
                [self createDisplayLink];
            }
        }
    }

    // Start the display link if we need to
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive || [UIApplication sharedApplication].applicationState == UIApplicationStateInactive) {

        BOOL mapViewVisible = self.isVisible;
        if (self.displayLink) {
            if (mapViewVisible && self.displayLink.isPaused) {
                [self startDisplayLink];
            }
            else if (!mapViewVisible && !self.displayLink.isPaused) {
                // Unlikely scenario
                [self stopDisplayLink];
            }
        }
    }

    // Reveal the snapshot view

    if (self.glSnapshotView && !self.glSnapshotView.isHidden) {
        [UIView transitionWithView:self
                          duration:0.25
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            self.glSnapshotView.hidden = YES;
        }
                        completion:^(BOOL finished) {
            [self.glSnapshotView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        }];
    }
}

- (BOOL)isDisplayLinkActive {
    MGLLogDebug(@"[%p]", self);
    return (self.displayLink && !self.displayLink.isPaused);
}

- (void)setHidden:(BOOL)hidden
{
    super.hidden = hidden;
    _displayLink.paused = ![self isVisible];
    
    if (hidden)
    {
        [self processPendingBlocks];
    }
}

- (void)tintColorDidChange
{
    for (UIView *subview in self.subviews) [self updateTintColorForView:subview];
}

- (void)updateTintColorForView:(UIView *)view
{
    // Don't update:
    //   - annotation views
    //   - attribution button (handled automatically)
    if ([view isEqual:self.annotationContainerView] || [view isEqual:self.attributionButton]) return;

    if ([view respondsToSelector:@selector(setTintColor:)]) view.tintColor = self.tintColor;

    for (UIView *subview in view.subviews) [self updateTintColorForView:subview];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

#pragma mark - Gestures -

- (void)touchesBegan:(__unused NSSet<UITouch *> *)touches withEvent:(__unused UIEvent *)event
{
    if (!self.zoomEnabled && !self.pitchEnabled && !self.rotateEnabled && !self.scrollEnabled)
    {
        return;
    };
    
    self.vmglMap.setGestureInProgress(false);
    if (self.userTrackingState == VMGLUserTrackingStateBegan)
    {
        [self setUserTrackingMode:VMGLUserTrackingModeNone animated:NO completionHandler:nil];
    }
    
    [self cancelTransitions];
}

- (void)notifyGestureDidBegin {
    BOOL animated = NO;

    [self cameraWillChangeAnimated:animated];
    self.vmglMap.setGestureInProgress(true);
    _changeDelimiterSuppressionDepth++;
}

- (void)notifyGestureDidEndWithDrift:(BOOL)drift {
    _changeDelimiterSuppressionDepth--;
    MGLAssert(_changeDelimiterSuppressionDepth >= 0,
             @"Unbalanced change delimiter suppression/unsuppression");
    if (_changeDelimiterSuppressionDepth == 0) {
        self.vmglMap.setGestureInProgress(false);
    }
    if ( ! drift)
    {
        BOOL animated = NO;
        [self cameraDidChangeAnimated:animated];
    }
}

- (BOOL)isSuppressingChangeDelimiters {
    return _changeDelimiterSuppressionDepth > 0;
}

- (BOOL)_shouldChangeFromCamera:(nonnull VMGLMapCamera *)oldCamera toCamera:(nonnull VMGLMapCamera *)newCamera
{
    // Check delegates first
    if ([self.delegate respondsToSelector:@selector(mapView:shouldChangeFromCamera:toCamera:reason:)])
    {
        return [self.delegate mapView:self shouldChangeFromCamera:oldCamera toCamera:newCamera reason:self.cameraChangeReasonBitmask];
    }
    else if ([self.delegate respondsToSelector:@selector(mapView:shouldChangeFromCamera:toCamera:)])
    {
        return [self.delegate mapView:self shouldChangeFromCamera:oldCamera toCamera:newCamera];
    }
    else
    {
        return YES;
    }
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)pan
{
    if ( ! self.isScrollEnabled) return;

    [self cancelTransitions];

    VMGLMapCamera *oldCamera = self.camera;

    self.cameraChangeReasonBitmask |= VMGLCameraChangeReasonGesturePan;

    if (pan.state == UIGestureRecognizerStateBegan)
    {
        self.userTrackingMode = VMGLUserTrackingModeNone;

        [self notifyGestureDidBegin];
    }
    else if (pan.state == UIGestureRecognizerStateChanged)
    {
        CGPoint delta = [pan translationInView:pan.view];

        VMGLMapCamera *toCamera = [self cameraByPanningWithTranslation:delta panGesture:pan];

        if ([self _shouldChangeFromCamera:oldCamera toCamera:toCamera])
        {
            switch(self.panScrollingMode){
                case VMGLPanScrollingModeVertical:
                  self.vmglMap.moveBy({ 0, delta.y });
                  break;
                case VMGLPanScrollingModeHorizontal:
                  self.vmglMap.moveBy({ delta.x, 0 });
                  break;
               default:
                  self.vmglMap.moveBy({ delta.x, delta.y });
            }

            [pan setTranslation:CGPointZero inView:pan.view];
        }

        [self cameraIsChanging];
    }
    else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled)
    {
        CGPoint velocity = [pan velocityInView:pan.view];
        if (self.decelerationRate == VMGLMapViewDecelerationRateImmediate || sqrtf(velocity.x * velocity.x + velocity.y * velocity.y) < 100)
        {
            // Not enough velocity to overcome friction
            velocity = CGPointZero;
        }

        BOOL drift = ! CGPointEqualToPoint(velocity, CGPointZero);
        if (drift)
        {
            CGPoint offset = CGPointMake(velocity.x * self.decelerationRate / 4, velocity.y * self.decelerationRate / 4);
            VMGLMapCamera *toCamera = [self cameraByPanningWithTranslation:offset panGesture:pan];

            if ([self _shouldChangeFromCamera:oldCamera toCamera:toCamera])
            {
                switch(self.panScrollingMode){
                   case VMGLPanScrollingModeVertical:
                      self.vmglMap.moveBy({ 0, offset.y }, VMGLDurationFromTimeInterval(self.decelerationRate));
                      break;
                   case VMGLPanScrollingModeHorizontal:
                      self.vmglMap.moveBy({ offset.x, 0 }, VMGLDurationFromTimeInterval(self.decelerationRate));
                      break;
                   default:
                      self.vmglMap.moveBy({ offset.x, offset.y }, VMGLDurationFromTimeInterval(self.decelerationRate));
                }
            }
        }

        [self notifyGestureDidEndWithDrift:drift];
    }

}

- (void)handlePinchGesture:(UIPinchGestureRecognizer *)pinch
{
    if ( ! self.isZoomEnabled) return;

    [self cancelTransitions];

    CGPoint centerPoint = [self anchorPointForGesture:pinch];
    if (self.anchorRotateOrZoomGesturesToCenterCoordinate) {
        if (pinch.numberOfTouches != 1 || pinch.state == UIGestureRecognizerStateEnded) {
            centerPoint = [self contentCenter];
        }
    }
    VMGLMapCamera *oldCamera = self.camera;

    self.cameraChangeReasonBitmask |= VMGLCameraChangeReasonGesturePinch;

    if (pinch.state == UIGestureRecognizerStateBegan)
    {
        self.scale = powf(2, [self zoomLevel]);

        if (abs(pinch.velocity) > abs(self.rotate.velocity)) {
            self.isZooming = YES;
        }
        [self notifyGestureDidBegin];
    }
    else if (pinch.state == UIGestureRecognizerStateChanged)
    {
        // Zoom limiting happens at the core level.
        CGFloat newScale = self.scale * pinch.scale;
        double newZoom = log2(newScale);

        // Calculates the final camera zoom, has no effect within current map camera.
        VMGLMapCamera *toCamera = [self cameraByZoomingToZoomLevel:newZoom aroundAnchorPoint:centerPoint];

        if ([self _shouldChangeFromCamera:oldCamera toCamera:toCamera])
        {
            self.vmglMap.jumpTo(mbgl::CameraOptions()
                                .withZoom(newZoom)
                                .withAnchor(mbgl::ScreenCoordinate { centerPoint.x, centerPoint.y }));

            // The gesture recognizer only reports the gesture’s current center
            // point, so use the previous center point to anchor the transition.
            // If the number of touches has changed, the remembered center point is
            // meaningless.
            if (self.userTrackingMode == VMGLUserTrackingModeNone && pinch.numberOfTouches == _previousPinchNumberOfTouches)
            {
                self.vmglMap.moveBy({centerPoint.x - _previousPinchCenterPoint.x, centerPoint.y - _previousPinchCenterPoint.y});
            }
        }
        [self cameraIsChanging];
    }
    else if (pinch.state == UIGestureRecognizerStateEnded || pinch.state == UIGestureRecognizerStateCancelled)
    {
        CGFloat velocity = pinch.velocity;
        if (isnan(velocity))
        {
            // UIPinchGestureRecognizer sometimes returns NaN for the velocity
            velocity = 0;
        }
        if (velocity > -0.5 && velocity < 3)
        {
            velocity = 0;
        }

        NSTimeInterval duration = (velocity > 0 ? 1 : 0.25) * self.decelerationRate;

        CGFloat scale = self.scale * pinch.scale;
        CGFloat newScale = scale;
        if (velocity >= 0)
        {
            newScale += scale * velocity * duration * 0.1;
        }
        else
        {
            newScale += scale / (velocity * duration) * 0.1;
        }

        if (newScale <= 0 || log2(newScale) < *self.vmglMap.getBounds().minZoom)
        {
            velocity = 0;
        }
        
        BOOL drift = velocity && duration;
        
        // Calculates the final camera zoom, this has no effect within current map camera.
        double zoom = log2(newScale);
        VMGLMapCamera *toCamera = [self cameraByZoomingToZoomLevel:zoom aroundAnchorPoint:centerPoint];

        if ( ! [self _shouldChangeFromCamera:oldCamera toCamera:toCamera])
        {
            drift = NO;
        }
        else
        {
            if (drift)
            {
                self.vmglMap.easeTo(mbgl::CameraOptions()
                                    .withZoom(zoom)
                                    .withAnchor(mbgl::ScreenCoordinate { centerPoint.x, centerPoint.y }),
                                    VMGLDurationFromTimeInterval(duration));
            }
        }

        self.isZooming = NO;
        [self notifyGestureDidEndWithDrift:drift];
        [self unrotateIfNeededForGesture];
    }

    _previousPinchCenterPoint = centerPoint;
    _previousPinchNumberOfTouches = pinch.numberOfTouches;
}

- (void)handleRotateGesture:(UIRotationGestureRecognizer *)rotate
{
    if ( ! self.isRotateEnabled) return;

    [self cancelTransitions];

    CGPoint centerPoint = [self anchorPointForGesture:rotate];
    if (self.anchorRotateOrZoomGesturesToCenterCoordinate) {
        centerPoint = [self contentCenter];
    }
    VMGLMapCamera *oldCamera = self.camera;

    self.cameraChangeReasonBitmask |= VMGLCameraChangeReasonGestureRotate;

    if ([[NSUserDefaults standardUserDefaults] objectForKey:VMGLRotationThresholdWhileZoomingKey]) {
        self.rotationThresholdWhileZooming = [[[NSUserDefaults standardUserDefaults] objectForKey:VMGLRotationThresholdWhileZoomingKey] floatValue];
    }
    // Check whether a zoom triggered by a pinch gesture is occurring and if the rotation threshold has been met.
    if (VMGLDegreesFromRadians(self.rotationBeforeThresholdMet) < self.rotationThresholdWhileZooming && self.isZooming && !self.isRotating) {
        self.rotationBeforeThresholdMet += fabs(rotate.rotation);
        if (self.anchorRotateOrZoomGesturesToCenterCoordinate) {
            self.rotationBeforeThresholdMet = 0;
        }
        rotate.rotation = 0;
        return;
    }

    if (rotate.state == UIGestureRecognizerStateBegan || ! self.isRotating)
    {
        self.angle = VMGLRadiansFromDegrees(*self.vmglMap.getCameraOptions().bearing) * -1;

        self.isRotating = YES;
        if (self.userTrackingMode != VMGLUserTrackingModeNone)
        {
            self.userTrackingMode = VMGLUserTrackingModeFollow;
        }

        self.shouldTriggerHapticFeedbackForCompass = NO;
        [self notifyGestureDidBegin];
    }
    if (rotate.state == UIGestureRecognizerStateChanged)
    {
        CGFloat newDegrees = VMGLDegreesFromRadians(self.angle + rotate.rotation) * -1;

        // constrain to +/-30 degrees when merely rotating like Apple does
        //
        if ( ! self.isRotationAllowed && std::abs(self.pinch.scale) < 10)
        {
            newDegrees = fminf(newDegrees,  30);
            newDegrees = fmaxf(newDegrees, -30);
        }

        VMGLMapCamera *toCamera = [self cameraByRotatingToDirection:newDegrees aroundAnchorPoint:centerPoint];

        if ([self _shouldChangeFromCamera:oldCamera toCamera:toCamera])
        {
            self.vmglMap.jumpTo(mbgl::CameraOptions()
                                    .withBearing(newDegrees)
                                    .withAnchor(mbgl::ScreenCoordinate { centerPoint.x, centerPoint.y}));
        }

        [self cameraIsChanging];

        // Trigger a light haptic feedback event when the user rotates to due north.
        if (@available(iOS 10.0, *))
        {
            if (self.isHapticFeedbackEnabled && fabs(newDegrees) <= 1 && self.shouldTriggerHapticFeedbackForCompass)
            {
                UIImpactFeedbackGenerator *hapticFeedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
                [hapticFeedback impactOccurred];

                self.shouldTriggerHapticFeedbackForCompass = NO;
            }
            else if (fabs(newDegrees) > 1)
            {
                self.shouldTriggerHapticFeedbackForCompass = YES;
            }
        }
    }
    else if ((rotate.state == UIGestureRecognizerStateEnded || rotate.state == UIGestureRecognizerStateCancelled))
    {
        self.rotationBeforeThresholdMet = 0;
        if (! self.isRotating) { return; }
        self.isRotating = NO;

        CGFloat velocity = rotate.velocity;
        CGFloat decelerationRate = self.decelerationRate;
        if (decelerationRate != VMGLMapViewDecelerationRateImmediate && fabs(velocity) > 3)
        {
            CGFloat radians = self.angle + rotate.rotation;
            CGFloat newRadians = radians + velocity * decelerationRate * 0.1;
            CGFloat newDegrees = VMGLDegreesFromRadians(newRadians) * -1;

            VMGLMapCamera *toCamera = [self cameraByRotatingToDirection:newDegrees aroundAnchorPoint:centerPoint];

            if ([self _shouldChangeFromCamera:oldCamera toCamera:toCamera])
            {
                self.vmglMap.easeTo(mbgl::CameraOptions()
                                    .withBearing(newDegrees)
                                    .withAnchor(mbgl::ScreenCoordinate { centerPoint.x, centerPoint.y }),
                                    VMGLDurationFromTimeInterval(decelerationRate));

                [self notifyGestureDidEndWithDrift:YES];
                __weak VMGLMapView *weakSelf = self;

                [self animateWithDelay:decelerationRate animations:^
                 {
                     [weakSelf unrotateIfNeededForGesture];
                 }];
            }
        }
        else
        {
            [self notifyGestureDidEndWithDrift:NO];
            [self unrotateIfNeededForGesture];
        }
    }
}

- (void)handleSingleTapGesture:(UITapGestureRecognizer *)singleTap
{
    if (singleTap.state != UIGestureRecognizerStateRecognized) return;

    if (self.mapViewProxyAccessibilityElement.accessibilityElementIsFocused)
    {
        id nextElement;
        if (_userLocationAnnotationIsSelected)
        {
            nextElement = self.userLocationAnnotationView;
        }
        else
        {
            if (_selectedAnnotationTag != VMGLAnnotationTagNotFound) {
                nextElement = _annotationContextsByAnnotationTag.at(_selectedAnnotationTag).accessibilityElement;
            }
        }
        [self deselectAnnotation:self.selectedAnnotation animated:YES];
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nextElement);

        return;
    }

    id<VMGLAnnotation> annotation = [self annotationForGestureRecognizer:singleTap persistingResults:YES];
    if (annotation)
    {
        CGPoint calloutPoint = [singleTap locationInView:self];
        CGRect positionRect = [self positioningRectForAnnotation:annotation defaultCalloutPoint:calloutPoint];
        [self selectAnnotation:annotation moveIntoView:YES animateSelection:YES calloutPositioningRect:positionRect completionHandler:nil];
    }
    else if (self.selectedAnnotation)
    {
        [self deselectAnnotation:self.selectedAnnotation animated:YES];
    }
}

/**
 Returns the annotation that would be selected by a tap gesture recognizer.

 This is used when a gesture is recognized, and to check if the gesture should be recognized.

 @param singleTap An in progress tap gesture recognizer.
 @param persist True to remember the cycleable set of annotations. @see annotationTagAtPoint:persistingResults
 */
- (nullable id <VMGLAnnotation>)annotationForGestureRecognizer:(UITapGestureRecognizer*)singleTap persistingResults:(BOOL)persist
{
    CGPoint tapPoint = [singleTap locationInView:self];

    if (self.userLocationVisible)
    {
        CGPoint tapPointForUserLocation;
        if (self.userLocationAnnotationView.hitTestLayer == self.userLocationAnnotationView.layer.presentationLayer)
        {
            tapPointForUserLocation = tapPoint;
        }
        else
        {
            // Get the tap point within the custom hit test layer.
            tapPointForUserLocation = [singleTap locationInView:self.userLocationAnnotationView];
        }

        CALayer *hitLayer = [self.userLocationAnnotationView.hitTestLayer hitTest:tapPointForUserLocation];

        if (hitLayer)
        {
            if ( ! _userLocationAnnotationIsSelected)
            {
                return self.userLocation;
            }
            return nil;
        }
    }
    
    VMGLAnnotationTag hitAnnotationTag = [self annotationTagAtPoint:tapPoint persistingResults:persist];
    if (hitAnnotationTag != VMGLAnnotationTagNotFound)
    {
        if (hitAnnotationTag != _selectedAnnotationTag)
        {
            id <VMGLAnnotation> annotation = [self annotationWithTag:hitAnnotationTag];
            MGLAssert(annotation, @"Cannot select nonexistent annotation with tag %llu", hitAnnotationTag);
            return annotation;
        }
    }

    return nil;
}

- (void)handleDoubleTapGesture:(UITapGestureRecognizer *)doubleTap
{
    if (doubleTap.state != UIGestureRecognizerStateRecognized) return;

    if ( ! self.isZoomEnabled) return;

    [self cancelTransitions];

    self.cameraChangeReasonBitmask |= VMGLCameraChangeReasonGestureZoomIn;

    VMGLMapCamera *oldCamera = self.camera;

    double newZoom = round(self.zoomLevel) + 1.0;

    CGPoint gesturePoint = [self anchorPointForGesture:doubleTap];

    VMGLMapCamera *toCamera = [self cameraByZoomingToZoomLevel:newZoom aroundAnchorPoint:gesturePoint];

    if ([self _shouldChangeFromCamera:oldCamera toCamera:toCamera])
    {
        mbgl::ScreenCoordinate center(gesturePoint.x, gesturePoint.y);
        self.vmglMap.easeTo(mbgl::CameraOptions()
                            .withZoom(newZoom)
                            .withAnchor(center),
                            VMGLDurationFromTimeInterval(VMGLAnimationDuration));

        __weak VMGLMapView *weakSelf = self;

        [self animateWithDelay:VMGLAnimationDuration animations:^
         {
             [weakSelf unrotateIfNeededForGesture];
         }];
    }
    else
    {
        [self unrotateIfNeededForGesture];
    }
}

- (void)handleTwoFingerTapGesture:(UITapGestureRecognizer *)twoFingerTap
{
    if (twoFingerTap.state != UIGestureRecognizerStateRecognized) return;

    if ( ! self.isZoomEnabled) return;

    if ([self zoomLevel] == *self.vmglMap.getBounds().minZoom) return;

    [self cancelTransitions];

    self.cameraChangeReasonBitmask |= VMGLCameraChangeReasonGestureZoomOut;

    VMGLMapCamera *oldCamera = self.camera;

    double newZoom = round(self.zoomLevel) - 1.0;

    CGPoint gesturePoint = [self anchorPointForGesture:twoFingerTap];

    VMGLMapCamera *toCamera = [self cameraByZoomingToZoomLevel:newZoom aroundAnchorPoint:gesturePoint];

    if ([self _shouldChangeFromCamera:oldCamera toCamera:toCamera])
    {
        mbgl::ScreenCoordinate center(gesturePoint.x, gesturePoint.y);
        self.vmglMap.easeTo(mbgl::CameraOptions()
                            .withZoom(newZoom)
                            .withAnchor(center),
                            VMGLDurationFromTimeInterval(VMGLAnimationDuration));

        __weak VMGLMapView *weakSelf = self;

        [self animateWithDelay:VMGLAnimationDuration animations:^
         {
             [weakSelf unrotateIfNeededForGesture];
         }];
    }
}

- (void)handleQuickZoomGesture:(UILongPressGestureRecognizer *)quickZoom
{
    if ( ! self.isZoomEnabled) return;

    [self cancelTransitions];

    self.cameraChangeReasonBitmask |= VMGLCameraChangeReasonGestureOneFingerZoom;

    if (quickZoom.state == UIGestureRecognizerStateBegan)
    {
        self.scale = powf(2, [self zoomLevel]);

        self.quickZoomStart = [quickZoom locationInView:quickZoom.view].y;

        [self notifyGestureDidBegin];
    }
    else if (quickZoom.state == UIGestureRecognizerStateChanged)
    {
        CGFloat distance = [quickZoom locationInView:quickZoom.view].y - self.quickZoomStart;

        CGFloat newZoom = MAX(log2f(self.scale) + (distance / 75), *self.vmglMap.getBounds().minZoom);

        if ([self zoomLevel] == newZoom) return;

        CGPoint centerPoint = [self anchorPointForGesture:quickZoom];
        
        VMGLMapCamera *oldCamera = self.camera;
        VMGLMapCamera *toCamera = [self cameraByZoomingToZoomLevel:newZoom aroundAnchorPoint:centerPoint];

        if ([self _shouldChangeFromCamera:oldCamera toCamera:toCamera])
        {
            self.vmglMap.jumpTo(mbgl::CameraOptions()
                                .withZoom(newZoom)
                                .withAnchor(mbgl::ScreenCoordinate { centerPoint.x, centerPoint.y }));
        }

        [self cameraIsChanging];
    }
    else if (quickZoom.state == UIGestureRecognizerStateEnded || quickZoom.state == UIGestureRecognizerStateCancelled)
    {
        [self notifyGestureDidEndWithDrift:NO];
        [self unrotateIfNeededForGesture];
    }
}

- (void)handleTwoFingerDragGesture:(UIPanGestureRecognizer *)twoFingerDrag
{
    if ( ! self.isPitchEnabled) return;

    [self cancelTransitions];

    self.cameraChangeReasonBitmask |= VMGLCameraChangeReasonGestureTilt;
    static CGFloat initialPitch;
    
    if (twoFingerDrag.state == UIGestureRecognizerStateBegan)
    {
        CGPoint midPoint = [twoFingerDrag translationInView:twoFingerDrag.view];
        // In the following if and for the first execution middlePoint
        // will be equal to dragGestureMiddlePoint and the resulting
        // gestureSlopeAngle will be 0º causing a small delay,
        // initializing dragGestureMiddlePoint with the current midPoint
        // but substracting one point from 'y' forces an initial 90º angle
        // making the gesture avoid the delay
        self.dragGestureMiddlePoint = CGPointMake(midPoint.x, midPoint.y-1);
        initialPitch = *self.vmglMap.getCameraOptions().pitch;
        [self notifyGestureDidBegin];
    }

    if (twoFingerDrag.state == UIGestureRecognizerStateBegan || twoFingerDrag.state == UIGestureRecognizerStateChanged)
    {
        if (twoFingerDrag.numberOfTouches != 2)
        {
            twoFingerDrag.state = UIGestureRecognizerStateEnded;
            return;
        }
        
        CGPoint leftTouchPoint = [twoFingerDrag locationOfTouch:0 inView:twoFingerDrag.view];
        CGPoint rightTouchPoint = [twoFingerDrag locationOfTouch:1 inView:twoFingerDrag.view];
        CLLocationDegrees fingerSlopeAngle = [self angleBetweenPoints:leftTouchPoint endPoint:rightTouchPoint];
        
        CGPoint middlePoint = [twoFingerDrag translationInView:twoFingerDrag.view];
        
        CLLocationDegrees gestureSlopeAngle = [self angleBetweenPoints:self.dragGestureMiddlePoint endPoint:middlePoint];
        self.dragGestureMiddlePoint = middlePoint;
        if (fabs(fingerSlopeAngle) < VMGLHorizontalTiltToleranceDegrees && fabs(gestureSlopeAngle) > 60.0 ) {
            
            CGFloat gestureDistance = middlePoint.y;
            CGFloat slowdown = 2.0;
            
            CGFloat pitchNew = initialPitch - (gestureDistance / slowdown);
            
            CGPoint centerPoint = [self anchorPointForGesture:twoFingerDrag];
            
            VMGLMapCamera *oldCamera = self.camera;
            VMGLMapCamera *toCamera = [self cameraByTiltingToPitch:pitchNew];
            
            if ([self _shouldChangeFromCamera:oldCamera toCamera:toCamera])
            {
                self.vmglMap.jumpTo(mbgl::CameraOptions()
                                    .withPitch(pitchNew)
                                    .withAnchor(mbgl::ScreenCoordinate { centerPoint.x, centerPoint.y }));
            }
            
            [self cameraIsChanging];
        
        }

        
    }
    else if (twoFingerDrag.state == UIGestureRecognizerStateEnded || twoFingerDrag.state == UIGestureRecognizerStateCancelled)
    {
        [self notifyGestureDidEndWithDrift:NO];
        [self unrotateIfNeededForGesture];
        self.dragGestureMiddlePoint = CGPointZero;
    }

}

- (VMGLMapCamera *)cameraByPanningWithTranslation:(CGPoint)endPoint panGesture:(UIPanGestureRecognizer *)pan
{
    VMGLMapCamera *panCamera = [self.camera copy];
    
    CGPoint centerPoint = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    CGPoint endCameraPoint = CGPointMake(centerPoint.x - endPoint.x, centerPoint.y - endPoint.y);
    CLLocationCoordinate2D panCoordinate = [self convertPoint:endCameraPoint toCoordinateFromView:pan.view];
    
    panCamera.centerCoordinate = panCoordinate;
    
    return panCamera;
}

- (VMGLMapCamera *)cameraByZoomingToZoomLevel:(double)zoom aroundAnchorPoint:(CGPoint)anchorPoint
{
    mbgl::ScreenCoordinate anchor = mbgl::ScreenCoordinate { anchorPoint.x, anchorPoint.y };
    mbgl::EdgeInsets padding = mbgl::EdgeInsets(anchor.y, anchor.x, self.size.height - anchor.y, self.size.width - anchor.x);
    mbgl::CameraOptions currentCameraOptions = self.vmglMap.getCameraOptions(padding);

    currentCameraOptions.zoom = mbgl::util::clamp(zoom, self.minimumZoomLevel, self.maximumZoomLevel);
    currentCameraOptions.anchor = anchor;
    VMGLCoordinateBounds bounds = VMGLCoordinateBoundsFromLatLngBounds(self.vmglMap.latLngBoundsForCamera(currentCameraOptions));
    
    return [self cameraThatFitsCoordinateBounds:bounds];
}

- (VMGLMapCamera *)cameraByRotatingToDirection:(CLLocationDirection)degrees aroundAnchorPoint:(CGPoint)anchorPoint
{
    mbgl::CameraOptions currentCameraOptions = self.vmglMap.getCameraOptions();
    
    VMGLMapCamera *camera;
    
    mbgl::ScreenCoordinate anchor = mbgl::ScreenCoordinate { anchorPoint.x, anchorPoint.y };
    currentCameraOptions.bearing = degrees;
    currentCameraOptions.anchor = anchor;
    camera = [self cameraForCameraOptions:currentCameraOptions];
    
    return camera;
}

- (VMGLMapCamera *)cameraByTiltingToPitch:(CGFloat)pitch
{
    mbgl::CameraOptions currentCameraOptions = self.vmglMap.getCameraOptions();
    
    VMGLMapCamera *camera;

    currentCameraOptions.pitch = pitch;
    camera = [self cameraForCameraOptions:currentCameraOptions];
    
    return camera;
}

- (CGPoint)anchorPointForGesture:(UIGestureRecognizer *)gesture {
    if (self.userTrackingMode != VMGLUserTrackingModeNone)
    {
        return self.userLocationAnnotationViewCenter;
    }

    // Special case for two-finger drag and quickzoom
    if ([gesture isKindOfClass:[UIPanGestureRecognizer class]] || [gesture isKindOfClass:[UILongPressGestureRecognizer class]])
    {
        return self.contentCenter;
    }

    return [gesture locationInView:gesture.view];
}

- (void)handleCalloutAccessoryTapGesture:(UITapGestureRecognizer *)tap
{
    if ([self.delegate respondsToSelector:@selector(mapView:annotation:calloutAccessoryControlTapped:)])
    {
        MGLAssert([tap.view isKindOfClass:[UIControl class]], @"Tapped view %@ is not a UIControl", tap.view);
        id <VMGLAnnotation> selectedAnnotation = self.selectedAnnotation;
        MGLAssert(selectedAnnotation, @"Selected annotation should not be nil.");
        [self.delegate mapView:self annotation:selectedAnnotation
            calloutAccessoryControlTapped:(UIControl *)tap.view];
    }
}

- (BOOL)calloutViewShouldHighlight:(__unused VMGLCompactCalloutView *)calloutView
{
    return [self.delegate respondsToSelector:@selector(mapView:tapOnCalloutForAnnotation:)];
}

- (void)calloutViewClicked:(__unused MGLSMCalloutView *)calloutView
{
    if ([self.delegate respondsToSelector:@selector(mapView:tapOnCalloutForAnnotation:)])
    {
        id <VMGLAnnotation> selectedAnnotation = self.selectedAnnotation;
        MGLAssert(selectedAnnotation, @"Selected annotation should not be nil.");
        [self.delegate mapView:self tapOnCalloutForAnnotation:selectedAnnotation];
    }
}

- (void)calloutViewTapped:(__unused VMGLCompactCalloutView *)calloutView
{
    if ([self.delegate respondsToSelector:@selector(mapView:tapOnCalloutForAnnotation:)])
    {
        id <VMGLAnnotation> selectedAnnotation = self.selectedAnnotation;
        MGLAssert(selectedAnnotation, @"Selected annotation should not be nil.");
        [self.delegate mapView:self tapOnCalloutForAnnotation:selectedAnnotation];
    }
}

- (void)calloutViewDidAppear:(UIView<VMGLCalloutView> *)calloutView
{
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil);
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, calloutView);
    
    [self updatePresentsWithTransaction];
    
    // TODO: Add sibling disappear method
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == _twoFingerDrag)
    {
        UIPanGestureRecognizer *panGesture = (UIPanGestureRecognizer *)gestureRecognizer;
        
        if (panGesture.minimumNumberOfTouches == 2)
        {
            CGPoint leftTouchPoint = [panGesture locationOfTouch:0 inView:panGesture.view];
            CGPoint rightTouchPoint = [panGesture locationOfTouch:1 inView:panGesture.view];
            
            CLLocationDegrees degrees = [self angleBetweenPoints:leftTouchPoint endPoint:rightTouchPoint];
            if (fabs(degrees) > VMGLHorizontalTiltToleranceDegrees) {
                return NO;
            }
        }
    }
    else if (gestureRecognizer == _singleTapGestureRecognizer)
    {
        // Gesture will be recognized if it could deselect an annotation
        if(!self.selectedAnnotation)
        {
            id<VMGLAnnotation> annotation = [self annotationForGestureRecognizer:(UITapGestureRecognizer*)gestureRecognizer persistingResults:NO];
            if (!annotation) {
                return NO;
            }
        }
    }
    else if (gestureRecognizer == _pan)
    {
        if (self.anchorRotateOrZoomGesturesToCenterCoordinate) {
            if (self.isZooming || self.isRotating) {
                return NO;
            }
        }
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    NSArray *validSimultaneousGestures = @[ self.pan, self.pinch, self.rotate ];
    return ([validSimultaneousGestures containsObject:gestureRecognizer] && [validSimultaneousGestures containsObject:otherGestureRecognizer]);
}

- (CLLocationDegrees)angleBetweenPoints:(CGPoint)originPoint endPoint:(CGPoint)endPoint
{
    if (originPoint.x > endPoint.x) {
        CGPoint swap = originPoint;
        originPoint = endPoint;
        endPoint = swap;
    }
    
    CGFloat x = (endPoint.x - originPoint.x);
    CGFloat y = (endPoint.y - originPoint.y);
    
    CGFloat angleInRadians = atan2(y, x);
    CLLocationDegrees angleInDegrees = VMGLDegreesFromRadians(angleInRadians);
    
    return angleInDegrees;
}

#pragma mark - Attribution -

- (void)showAttribution:(id)sender
{
    BOOL shouldShowVersion = [sender isKindOfClass:[UILongPressGestureRecognizer class]];
    if (shouldShowVersion)
    {
        UILongPressGestureRecognizer *longPress = (UILongPressGestureRecognizer *)sender;
        if (longPress.state != UIGestureRecognizerStateBegan)
        {
            return;
        }
    }

    NSString *actionSheetTitle = NSLocalizedStringWithDefaultValue(@"SDK_NAME", nil, nil, @"Mapbox Maps SDK for iOS", @"Action sheet title");
    UIAlertController *attributionController = [UIAlertController alertControllerWithTitle:actionSheetTitle
                                                                                   message:nil
                                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    if (shouldShowVersion)
    {
        attributionController.title = [actionSheetTitle stringByAppendingFormat:@" %@", [NSBundle mgl_frameworkInfoDictionary][@"MGLSemanticVersionString"]];
    }
    
    NSArray *attributionInfos = [self.style attributionInfosWithFontSize:[UIFont buttonFontSize] linkColor:nil];
    for (VMGLAttributionInfo *attributionInfo in attributionInfos)
    {
        UIAlertAction *action = [UIAlertAction actionWithTitle:[attributionInfo.title.string mgl_titleCasedStringWithLocale:[NSLocale currentLocale]]
                                                         style:UIAlertActionStyleDefault
                                                       handler:nil];
        [attributionController addAction:action];
    }

    NSString *cancelTitle = NSLocalizedStringWithDefaultValue(@"CANCEL", nil, nil, @"Cancel", @"Title of button for dismissing attribution action sheet");
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelTitle
                                                           style:UIAlertActionStyleCancel
                                                         handler:NULL];
    [attributionController addAction:cancelAction];
    
    attributionController.popoverPresentationController.sourceView = self;
    attributionController.popoverPresentationController.sourceRect = self.attributionButton.frame;
    
    UIViewController *viewController = [self.window.rootViewController mgl_topMostViewController];
    [viewController presentViewController:attributionController animated:YES completion:NULL];
    self.attributionController = attributionController;
}

#pragma mark - Properties -

static void *windowScreenContext = &windowScreenContext;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"coordinate"] && [object conformsToProtocol:@protocol(VMGLAnnotation)] && ![object isKindOfClass:[VMGLMultiPoint class]])
    {
        id <VMGLAnnotation> annotation = object;
        VMGLAnnotationTag annotationTag = (VMGLAnnotationTag)(NSUInteger)context;
        // We can get here because a subclass registered itself as an observer
        // of the coordinate key path of a non-multipoint annotation but failed
        // to handle the change. This check deters us from treating the
        // subclass’s context as an annotation tag. If the context happens to
        // match a valid annotation tag, the annotation will be unnecessarily
        // but safely updated.
        if (annotation == [self annotationWithTag:annotationTag])
        {
            const mbgl::Point<double> point = VMGLPointFromLocationCoordinate2D(annotation.coordinate);

            if (annotationTag != VMGLAnnotationTagNotFound) {
                VMGLAnnotationContext &annotationContext = _annotationContextsByAnnotationTag.at(annotationTag);
                if (annotationContext.annotationView)
                {
                    // Redundantly move the associated annotation view outside the scope of the animation-less transaction block in -updateAnnotationViews.
                    annotationContext.annotationView.center = [self convertCoordinate:annotationContext.annotation.coordinate toPointToView:self];
                }

                VMGLAnnotationImage *annotationImage = [self imageOfAnnotationWithTag:annotationTag];
                NSString *symbolName = annotationImage.styleIconIdentifier;

                // Update the annotation’s backing geometry to match the annotation model object. Any associated annotation view is also moved by side effect. However, -updateAnnotationViews disables the view’s animation actions, because it can’t distinguish between moves due to the viewport changing and moves due to the annotation’s coordinate changing.
                self.vmglMap.updateAnnotation(annotationTag, mbgl::SymbolAnnotation { point, symbolName.UTF8String });
                [self updateCalloutView];
            }
        }
    }
    else if ([keyPath isEqualToString:@"coordinates"] && [object isKindOfClass:[VMGLMultiPoint class]])
    {
        VMGLMultiPoint *annotation = object;
        VMGLAnnotationTag annotationTag = (VMGLAnnotationTag)(NSUInteger)context;
        // We can get here because a subclass registered itself as an observer
        // of the coordinates key path of a multipoint annotation but failed
        // to handle the change. This check deters us from treating the
        // subclass’s context as an annotation tag. If the context happens to
        // match a valid annotation tag, the annotation will be unnecessarily
        // but safely updated.
        if (annotation == [self annotationWithTag:annotationTag])
        {
            // Update the annotation’s backing geometry to match the annotation model object.
            self.vmglMap.updateAnnotation(annotationTag, [annotation annotationObjectWithDelegate:self]);
            [self updateCalloutView];
        }
    }
    else if (context == windowScreenContext)
    {
        if ([keyPath isEqualToString:@"screen"] ||
            [keyPath isEqualToString:@"windowScene"]) {
            [self destroyDisplayLink];
            [self didBecomeActive:nil];
        }
    }
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingZoomEnabled
{
    return [NSSet setWithObject:@"allowsZooming"];
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingScrollEnabled
{
    return [NSSet setWithObject:@"allowsScrolling"];
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingRotateEnabled
{
    return [NSSet setWithObject:@"allowsRotating"];
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingPitchEnabled
{
    return [NSSet setWithObject:@"allowsTilting"];
}

- (VMGLMapDebugMaskOptions)debugMask
{
    if (!_mbglMap)
    {
        NSAssert(self.terminated, @"_mbglMap should only be unavailable during app termination");
        return self.residualDebugMask;
    }
    
    mbgl::VMGLDebugOptions options = self.vmglMap.getDebug();
    VMGLMapDebugMaskOptions mask = 0;
    if (options & mbgl::VMGLDebugOptions::TileBorders)
    {
        mask |= VMGLMapDebugTileBoundariesMask;
    }
    if (options & mbgl::VMGLDebugOptions::ParseStatus)
    {
        mask |= VMGLMapDebugTileInfoMask;
    }
    if (options & mbgl::VMGLDebugOptions::Timestamps)
    {
        mask |= VMGLMapDebugTimestampsMask;
    }
    if (options & mbgl::VMGLDebugOptions::Collision)
    {
        mask |= VMGLMapDebugCollisionBoxesMask;
    }
    if (options & mbgl::VMGLDebugOptions::Overdraw)
    {
        mask |= VMGLMapDebugOverdrawVisualizationMask;
    }
    return mask;
}

- (void)setDebugMask:(VMGLMapDebugMaskOptions)debugMask
{
    if (!_mbglMap)
    {
        return;
    }

    mbgl::VMGLDebugOptions options = mbgl::VMGLDebugOptions::NoDebug;
    if (debugMask & VMGLMapDebugTileBoundariesMask)
    {
        options |= mbgl::VMGLDebugOptions::TileBorders;
    }
    if (debugMask & VMGLMapDebugTileInfoMask)
    {
        options |= mbgl::VMGLDebugOptions::ParseStatus;
    }
    if (debugMask & VMGLMapDebugTimestampsMask)
    {
        options |= mbgl::VMGLDebugOptions::Timestamps;
    }
    if (debugMask & VMGLMapDebugCollisionBoxesMask)
    {
        options |= mbgl::VMGLDebugOptions::Collision;
    }
    if (debugMask & VMGLMapDebugOverdrawVisualizationMask)
    {
        options |= mbgl::VMGLDebugOptions::Overdraw;
    }
    self.vmglMap.setDebug(options);
}

- (void)resetNorth
{
    MGLLogInfo(@"Resetting the map rotation to a northern heading — a direction of 0 degrees.");
    [self resetNorthAnimated:YES];
}

- (void)resetNorthAnimated:(BOOL)animated
{
    self.cameraChangeReasonBitmask |= VMGLCameraChangeReasonResetNorth;

    [self setDirection:0 animated:animated];
}

- (void)resetPosition
{
    MGLLogInfo(@"Resetting the map to the current style’s default viewport.");
    auto camera = self.vmglMap.getStyle().getDefaultCamera();
    
    double pitch        = camera.pitch ? *camera.pitch : 0.0;
    double bearing      = camera.bearing ? *camera.bearing : 0.0;
    double zoom         = camera.zoom ? *camera.zoom : 0.0;
    mbgl::LatLng center = camera.center ? *camera.center : mbgl::LatLng();
    
    CLLocationDirection heading = mbgl::util::wrap(bearing, 0., 360.);
    CLLocationDistance altitude = MGLAltitudeForZoomLevel(zoom, pitch, 0, self.frame.size);
    self.camera = [VMGLMapCamera cameraLookingAtCenterCoordinate:VMGLLocationCoordinate2DFromLatLng(center)
                                                       altitude:altitude
                                                          pitch:pitch
                                                        heading:heading];
}

- (void)setZoomEnabled:(BOOL)zoomEnabled
{
    MGLLogDebug(@"Setting zoomEnabled: %@", VMGLStringFromBOOL(zoomEnabled));
    _zoomEnabled = zoomEnabled;
    self.pinch.enabled = zoomEnabled;
    self.doubleTap.enabled = zoomEnabled;
    self.quickZoom.enabled = zoomEnabled;
    self.twoFingerTap.enabled = zoomEnabled;
}

- (void)setScrollEnabled:(BOOL)scrollEnabled
{
    MGLLogDebug(@"Setting scrollEnabled: %@", VMGLStringFromBOOL(scrollEnabled));
    _scrollEnabled = scrollEnabled;
    self.pan.enabled = scrollEnabled;
}

- (void)setRotateEnabled:(BOOL)rotateEnabled
{
    MGLLogDebug(@"Setting rotateEnabled: %@", VMGLStringFromBOOL(rotateEnabled));
    _rotateEnabled = rotateEnabled;
    self.rotate.enabled = rotateEnabled;
}

- (void)setPitchEnabled:(BOOL)pitchEnabled
{
    MGLLogDebug(@"Setting pitchEnabled: %@", VMGLStringFromBOOL(pitchEnabled));
    _pitchEnabled = pitchEnabled;
    self.twoFingerDrag.enabled = pitchEnabled;
}

- (void)setShowsScale:(BOOL)showsScale
{
    MGLLogDebug(@"Setting showsScale: %@", VMGLStringFromBOOL(showsScale));
    _showsScale = showsScale;
    self.scaleBar.hidden = !showsScale;

    if (showsScale)
    {
        [self updateScaleBar];
    }
}

- (void)setScaleBarShouldShowDarkStyles:(BOOL)scaleBarShouldShowDarkStyles {
    
    _scaleBarShouldShowDarkStyles = scaleBarShouldShowDarkStyles;
    [(VMGLScaleBar *)self.scaleBar setShouldShowDarkStyles:scaleBarShouldShowDarkStyles];
    
}

- (void)setScaleBarUsesMetricSystem:(BOOL)scaleBarUsesMetricSystem {
    
    _scaleBarUsesMetricSystem = scaleBarUsesMetricSystem;
    [(VMGLScaleBar *)self.scaleBar setUsesMetricSystem:scaleBarUsesMetricSystem];
    
}

- (void)setPrefetchesTiles:(BOOL)prefetchesTiles
{
    self.vmglMap.setPrefetchZoomDelta(prefetchesTiles ? mbgl::util::DEFAULT_PREFETCH_ZOOM_DELTA : 0);
}

- (BOOL)prefetchesTiles
{
    return self.vmglMap.getPrefetchZoomDelta() > 0 ? YES : NO;
}

#pragma mark - Accessibility -

- (NSString *)accessibilityValue
{
    NSMutableArray *facts = [NSMutableArray array];
    
    double zoomLevel = round(self.zoomLevel + 1);
    [facts addObject:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"MAP_A11Y_VALUE_ZOOM", nil, nil, @"Zoom %dx.", @"Map accessibility value; {zoom level}"), (int)zoomLevel]];
    
    NSInteger annotationCount = self.accessibilityAnnotationCount;
    if (annotationCount) {
        [facts addObject:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"MAP_A11Y_VALUE_ANNOTATIONS", nil, nil, @"%ld annotation(s) visible.", @"Map accessibility value; {number of visible annotations}"), (long)self.accessibilityAnnotationCount]];
    }
    
    NSArray *placeFeatures = self.visiblePlaceFeatures;
    if (placeFeatures.count) {
        NSMutableArray *placesArray = [NSMutableArray arrayWithCapacity:placeFeatures.count];
        NSMutableSet *placesSet = [NSMutableSet setWithCapacity:placeFeatures.count];
        for (id <VMGLFeature> placeFeature in placeFeatures.reverseObjectEnumerator) {
            NSString *name = [placeFeature attributeForKey:@"name"];
            if (![placesSet containsObject:name]) {
                [placesArray addObject:name];
                [placesSet addObject:name];
            }
            if (placesArray.count >= 3) {
                break;
            }
        }
        NSString *placesString = [placesArray componentsJoinedByString:NSLocalizedStringWithDefaultValue(@"LIST_SEPARATOR", nil, nil, @", ", @"List separator")];
        [facts addObject:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"MAP_A11Y_VALUE_PLACES", nil, nil, @"Places visible: %@.", @"Map accessibility value; {list of visible places}"), placesString]];
    }
    
    NSArray *roadFeatures = self.visibleRoadFeatures;
    if (roadFeatures.count) {
        [facts addObject:[NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"MAP_A11Y_VALUE_ROADS", nil, nil, @"%ld road(s) visible.", @"Map accessibility value; {number of visible roads}"), roadFeatures.count]];
    }
    
    NSString *value = [facts componentsJoinedByString:@" "];
    return value;
}

- (NSArray<id <VMGLFeature>> *)visiblePlaceFeatures
{
    if (!_visiblePlaceFeatures)
    {
        NSArray *placeStyleLayerIdentifiers = [self.style.placeStyleLayers valueForKey:@"identifier"];
        _visiblePlaceFeatures = [self visibleFeaturesInRect:self.bounds inStyleLayersWithIdentifiers:[NSSet setWithArray:placeStyleLayerIdentifiers]];
    }
    return _visiblePlaceFeatures;
}

- (NSArray<id <VMGLFeature>> *)visibleRoadFeatures
{
    if (!_visibleRoadFeatures)
    {
        NSArray *roadStyleLayerIdentifiers = [self.style.roadStyleLayers valueForKey:@"identifier"];
        _visibleRoadFeatures = [self visibleFeaturesInRect:self.bounds inStyleLayersWithIdentifiers:[NSSet setWithArray:roadStyleLayerIdentifiers]];
    }
    return _visibleRoadFeatures;
}

- (CGRect)accessibilityFrame
{
    CGRect frame = [super accessibilityFrame];
    UIViewController *viewController = self.mgl_viewControllerForLayoutGuides;
    if (viewController)
    {
        CGFloat topInset = viewController.topLayoutGuide.length;
        frame.origin.y += topInset;
        frame.size.height -= topInset + viewController.bottomLayoutGuide.length;
    }
    return frame;
}

- (UIBezierPath *)accessibilityPath
{
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:self.accessibilityFrame];

    // Exclude any visible annotation callout view.
    if (self.calloutViewForSelectedAnnotation)
    {
        UIBezierPath *calloutViewPath = [UIBezierPath bezierPathWithRect:self.calloutViewForSelectedAnnotation.frame];
        [path appendPath:calloutViewPath];
    }

    return path;
}

- (NSInteger)accessibilityElementCount
{
    if (self.calloutViewForSelectedAnnotation)
    {
        return 2 /* calloutViewForSelectedAnnotation, mapViewProxyAccessibilityElement */;
    }
    return !!self.userLocationAnnotationView + self.accessibilityAnnotationCount + self.visiblePlaceFeatures.count + self.visibleRoadFeatures.count + 2 /* compass, attributionButton */;
}

- (NSInteger)accessibilityAnnotationCount
{
    std::vector<VMGLAnnotationTag> visibleAnnotations = [self annotationTagsInRect:self.bounds];
    return visibleAnnotations.size();
}

- (id)accessibilityElementAtIndex:(NSInteger)index
{
    if (self.calloutViewForSelectedAnnotation)
    {
        if (index == 0)
        {
            return self.calloutViewForSelectedAnnotation;
        }
        if (index == 1)
        {
            self.mapViewProxyAccessibilityElement.accessibilityFrame = self.accessibilityFrame;
            self.mapViewProxyAccessibilityElement.accessibilityPath = self.accessibilityPath;
            return self.mapViewProxyAccessibilityElement;
        }
        return nil;
    }
    
    // Compass
    NSInteger compassIndex = 0;
    if (index == compassIndex)
    {
        return self.compassView;
    }
    
    // User location annotation
    NSRange userLocationAnnotationRange = NSMakeRange(compassIndex + 1, !!self.userLocationAnnotationView);
    if (NSLocationInRange(index, userLocationAnnotationRange))
    {
        return self.userLocationAnnotationView;
    }
    
    CGPoint centerPoint = self.contentCenter;
    if (self.userTrackingMode != VMGLUserTrackingModeNone)
    {
        centerPoint = self.userLocationAnnotationViewCenter;
    }
    
    // Visible annotations
    std::vector<VMGLAnnotationTag> visibleAnnotations = [self annotationTagsInRect:self.bounds];
    NSRange visibleAnnotationRange = NSMakeRange(NSMaxRange(userLocationAnnotationRange), visibleAnnotations.size());
    if (NSLocationInRange(index, visibleAnnotationRange))
    {
        std::sort(visibleAnnotations.begin(), visibleAnnotations.end());
        std::sort(visibleAnnotations.begin(), visibleAnnotations.end(), [&](const VMGLAnnotationTag tagA, const VMGLAnnotationTag tagB) {
            CLLocationCoordinate2D coordinateA = [[self annotationWithTag:tagA] coordinate];
            CLLocationCoordinate2D coordinateB = [[self annotationWithTag:tagB] coordinate];
            CGPoint pointA = [self convertCoordinate:coordinateA toPointToView:self];
            CGPoint pointB = [self convertCoordinate:coordinateB toPointToView:self];
            CGFloat deltaA = hypot(pointA.x - centerPoint.x, pointA.y - centerPoint.y);
            CGFloat deltaB = hypot(pointB.x - centerPoint.x, pointB.y - centerPoint.y);
            return deltaA < deltaB;
        });
        
        NSUInteger annotationIndex = index - visibleAnnotationRange.location;
        VMGLAnnotationTag annotationTag = visibleAnnotations[annotationIndex];
        MGLAssert(annotationTag != VMGLAnnotationTagNotFound, @"Can’t get accessibility element for nonexistent or invisible annotation at index %li.", (long)index);
        return [self accessibilityElementForAnnotationWithTag:annotationTag];
    }
    
    // Visible place features
    NSArray *visiblePlaceFeatures = self.visiblePlaceFeatures;
    NSRange visiblePlaceFeatureRange = NSMakeRange(NSMaxRange(visibleAnnotationRange), visiblePlaceFeatures.count);
    if (NSLocationInRange(index, visiblePlaceFeatureRange))
    {
        visiblePlaceFeatures = [visiblePlaceFeatures sortedArrayUsingComparator:^NSComparisonResult(id <VMGLFeature> _Nonnull featureA, id <VMGLFeature> _Nonnull featureB) {
            CGPoint pointA = [self convertCoordinate:featureA.coordinate toPointToView:self];
            CGPoint pointB = [self convertCoordinate:featureB.coordinate toPointToView:self];
            CGFloat deltaA = hypot(pointA.x - centerPoint.x, pointA.y - centerPoint.y);
            CGFloat deltaB = hypot(pointB.x - centerPoint.x, pointB.y - centerPoint.y);
            return [@(deltaA) compare:@(deltaB)];
        }];
        
        id <VMGLFeature> feature = visiblePlaceFeatures[index - visiblePlaceFeatureRange.location];
        return [self accessibilityElementForPlaceFeature:feature];
    }
    
    // Visible road features
    NSArray *visibleRoadFeatures = self.visibleRoadFeatures;
    NSRange visibleRoadFeatureRange = NSMakeRange(NSMaxRange(visiblePlaceFeatureRange), visibleRoadFeatures.count);
    if (NSLocationInRange(index, visibleRoadFeatureRange))
    {
        visibleRoadFeatures = [visibleRoadFeatures sortedArrayUsingComparator:^NSComparisonResult(id <VMGLFeature> _Nonnull featureA, id <VMGLFeature> _Nonnull featureB) {
            CGPoint pointA = [self convertCoordinate:featureA.coordinate toPointToView:self];
            CGPoint pointB = [self convertCoordinate:featureB.coordinate toPointToView:self];
            CGFloat deltaA = hypot(pointA.x - centerPoint.x, pointA.y - centerPoint.y);
            CGFloat deltaB = hypot(pointB.x - centerPoint.x, pointB.y - centerPoint.y);
            return [@(deltaA) compare:@(deltaB)];
        }];
        
        id <VMGLFeature> feature = visibleRoadFeatures[index - visibleRoadFeatureRange.location];
        return [self accessibilityElementForRoadFeature:feature];
    }
    
    // Attribution button
    NSInteger attributionButtonIndex = NSMaxRange(visibleRoadFeatureRange);
    if (index == attributionButtonIndex)
    {
        return self.attributionButton;
    }
    
    MGLAssert(NO, @"Index %ld not in recognized accessibility element ranges. "
             @"User location annotation range: %@; visible annotation range: %@; "
             @"visible place feature range: %@; visible road feature range: %@.",
             (long)index, NSStringFromRange(userLocationAnnotationRange),
             NSStringFromRange(visibleAnnotationRange), NSStringFromRange(visiblePlaceFeatureRange),
             NSStringFromRange(visibleRoadFeatureRange));
    return nil;
}

/**
 Returns an accessibility element corresponding to a visible annotation with the given tag.
 
 @param annotationTag Tag of the annotation represented by the accessibility element to return.
 */
- (id)accessibilityElementForAnnotationWithTag:(VMGLAnnotationTag)annotationTag
{
    MGLAssert(_annotationContextsByAnnotationTag.count(annotationTag), @"Missing annotation for tag %llu.", annotationTag);
    VMGLAnnotationContext &annotationContext = _annotationContextsByAnnotationTag.at(annotationTag);
    id <VMGLAnnotation> annotation = annotationContext.annotation;
    
    // Let the annotation view serve as its own accessibility element.
    VMGLAnnotationView *annotationView = annotationContext.annotationView;
    if (annotationView && annotationView.superview)
    {
        return annotationView;
    }
    
    // Lazily create an accessibility element for the found annotation.
    if ( ! annotationContext.accessibilityElement)
    {
        annotationContext.accessibilityElement = [[VMGLAnnotationAccessibilityElement alloc] initWithAccessibilityContainer:self tag:annotationTag];
    }
    
    // Update the accessibility element.
    VMGLAnnotationImage *annotationImage = [self imageOfAnnotationWithTag:annotationTag];
    CGRect annotationFrame = [self frameOfImage:annotationImage.image centeredAtCoordinate:annotation.coordinate];
    CGPoint annotationFrameCenter = CGPointMake(CGRectGetMidX(annotationFrame), CGRectGetMidY(annotationFrame));
    CGRect minimumFrame = CGRectInset({ annotationFrameCenter, CGSizeZero },
                                      -VMGLAnnotationAccessibilityElementMinimumSize.width / 2,
                                      -VMGLAnnotationAccessibilityElementMinimumSize.height / 2);
    annotationFrame = CGRectUnion(annotationFrame, minimumFrame);
    CGRect screenRect = UIAccessibilityConvertFrameToScreenCoordinates(annotationFrame, self);
    annotationContext.accessibilityElement.accessibilityFrame = screenRect;
    
    if ([annotation respondsToSelector:@selector(title)])
    {
        annotationContext.accessibilityElement.accessibilityLabel = annotation.title;
    }
    if ([annotation respondsToSelector:@selector(subtitle)])
    {
        annotationContext.accessibilityElement.accessibilityValue = annotation.subtitle;
    }
    
    return annotationContext.accessibilityElement;
}

/**
 Returns an accessibility element corresponding to the given place feature.
 
 @param feature The place feature represented by the accessibility element.
 */
- (id)accessibilityElementForPlaceFeature:(id <VMGLFeature>)feature
{
    if (!_featureAccessibilityElements)
    {
        _featureAccessibilityElements = [NSMutableSet set];
    }
    
    VMGLFeatureAccessibilityElement *element = [_featureAccessibilityElements objectsPassingTest:^BOOL(VMGLFeatureAccessibilityElement * _Nonnull testElement, BOOL * _Nonnull stop) {
        return testElement.feature.identifier && ![testElement.feature.identifier isEqual:@0] && [testElement.feature.identifier isEqual:feature.identifier];
    }].anyObject;
    if (!element)
    {
        element = [[VMGLPlaceFeatureAccessibilityElement alloc] initWithAccessibilityContainer:self feature:feature];
    }
    CGPoint center = [self convertCoordinate:feature.coordinate toPointToView:self];
    CGRect annotationFrame = CGRectInset({center, CGSizeZero}, -VMGLAnnotationAccessibilityElementMinimumSize.width / 2, -VMGLAnnotationAccessibilityElementMinimumSize.width / 2);
    CGRect screenRect = UIAccessibilityConvertFrameToScreenCoordinates(annotationFrame, self);
    element.accessibilityFrame = screenRect;
    
    [_featureAccessibilityElements addObject:element];
    
    return element;
}

/**
 Returns an accessibility element corresponding to the given road feature.
 
 @param feature The road feature represented by the accessibility element.
 */
- (id)accessibilityElementForRoadFeature:(id <VMGLFeature>)feature
{
    if (!_featureAccessibilityElements)
    {
        _featureAccessibilityElements = [NSMutableSet set];
    }
    
    VMGLFeatureAccessibilityElement *element = [_featureAccessibilityElements objectsPassingTest:^BOOL(VMGLFeatureAccessibilityElement * _Nonnull testElement, BOOL * _Nonnull stop) {
        return testElement.feature.identifier && ![testElement.feature.identifier isEqual:@0] && [testElement.feature.identifier isEqual:feature.identifier];
    }].anyObject;
    if (!element)
    {
        element = [[VMGLRoadFeatureAccessibilityElement alloc] initWithAccessibilityContainer:self feature:feature];
    }
    
    UIBezierPath *path;
    if ([feature isKindOfClass:[MGLPointFeature class]])
    {
        CGPoint center = [self convertCoordinate:feature.coordinate toPointToView:self];
        CGRect annotationFrame = CGRectInset({center, CGSizeZero}, -VMGLAnnotationAccessibilityElementMinimumSize.width / 2, -VMGLAnnotationAccessibilityElementMinimumSize.width / 2);
        CGRect screenRect = UIAccessibilityConvertFrameToScreenCoordinates(annotationFrame, self);
        element.accessibilityFrame = screenRect;
    }
    else if ([feature isKindOfClass:[VMGLPolylineFeature class]])
    {
        path = [self pathOfPolyline:(VMGLPolyline *)feature];
    }
    else if ([feature isKindOfClass:[VMGLMultiPolylineFeature class]])
    {
        path = [UIBezierPath bezierPath];
        for (VMGLPolyline *polyline in [(VMGLMultiPolylineFeature *)feature polylines])
        {
            [path appendPath:[self pathOfPolyline:polyline]];
        }
    }
    
    if (path)
    {
        CGPathRef strokedCGPath = CGPathCreateCopyByStrokingPath(path.CGPath, NULL, VMGLAnnotationAccessibilityElementMinimumSize.width, kCGLineCapButt, kCGLineJoinMiter, 0);
        UIBezierPath *strokedPath = [UIBezierPath bezierPathWithCGPath:strokedCGPath];
        CGPathRelease(strokedCGPath);
        UIBezierPath *screenPath = UIAccessibilityConvertPathToScreenCoordinates(strokedPath, self);
        element.accessibilityPath = screenPath;
    }
    
    [_featureAccessibilityElements addObject:element];
    
    return element;
}

- (UIBezierPath *)pathOfPolyline:(VMGLPolyline *)polyline
{
    CLLocationCoordinate2D *coordinates = polyline.coordinates;
    NSUInteger pointCount = polyline.pointCount;
    UIBezierPath *path = [UIBezierPath bezierPath];
    for (NSUInteger i = 0; i < pointCount; i++)
    {
        CGPoint point = [self convertCoordinate:coordinates[i] toPointToView:self];
        if (i)
        {
            [path addLineToPoint:point];
        }
        else
        {
            [path moveToPoint:point];
        }
    }
    return path;
}

- (NSInteger)indexOfAccessibilityElement:(id)element
{
    if (self.calloutViewForSelectedAnnotation)
    {
        return [@[self.calloutViewForSelectedAnnotation, self.mapViewProxyAccessibilityElement]
                indexOfObject:element];
    }
    
    // Compass
    NSUInteger compassIndex = 0;
    if (element == self.compassView)
    {
        return compassIndex;
    }
    
    // User location annotation
    NSRange userLocationAnnotationRange = NSMakeRange(compassIndex + 1, !!self.userLocationAnnotationView);
    if (element == self.userLocationAnnotationView)
    {
        return userLocationAnnotationRange.location;
    }
    
    CGPoint centerPoint = self.contentCenter;
    if (self.userTrackingMode != VMGLUserTrackingModeNone)
    {
        centerPoint = self.userLocationAnnotationViewCenter;
    }
    
    // Visible annotations
    std::vector<VMGLAnnotationTag> visibleAnnotations = [self annotationTagsInRect:self.bounds];
    NSRange visibleAnnotationRange = NSMakeRange(NSMaxRange(userLocationAnnotationRange), visibleAnnotations.size());
    VMGLAnnotationTag tag = VMGLAnnotationTagNotFound;
    if ([element isKindOfClass:[VMGLAnnotationView class]])
    {
        id <VMGLAnnotation> annotation = [(VMGLAnnotationView *)element annotation];
        tag = [self annotationTagForAnnotation:annotation];
    }
    else if ([element isKindOfClass:[VMGLAnnotationAccessibilityElement class]])
    {
        tag = [(VMGLAnnotationAccessibilityElement *)element tag];
    }
    
    if (tag != VMGLAnnotationTagNotFound)
    {
        std::sort(visibleAnnotations.begin(), visibleAnnotations.end());
        std::sort(visibleAnnotations.begin(), visibleAnnotations.end(), [&](const VMGLAnnotationTag tagA, const VMGLAnnotationTag tagB) {
            CLLocationCoordinate2D coordinateA = [[self annotationWithTag:tagA] coordinate];
            CLLocationCoordinate2D coordinateB = [[self annotationWithTag:tagB] coordinate];
            CGPoint pointA = [self convertCoordinate:coordinateA toPointToView:self];
            CGPoint pointB = [self convertCoordinate:coordinateB toPointToView:self];
            CGFloat deltaA = hypot(pointA.x - centerPoint.x, pointA.y - centerPoint.y);
            CGFloat deltaB = hypot(pointB.x - centerPoint.x, pointB.y - centerPoint.y);
            return deltaA < deltaB;
        });
        
        auto foundElement = std::find(visibleAnnotations.begin(), visibleAnnotations.end(), tag);
        if (foundElement == visibleAnnotations.end())
        {
            return NSNotFound;
        }
        return visibleAnnotationRange.location + std::distance(visibleAnnotations.begin(), foundElement);
    }
    
    // Visible place features
    NSArray *visiblePlaceFeatures = self.visiblePlaceFeatures;
    NSRange visiblePlaceFeatureRange = NSMakeRange(NSMaxRange(visibleAnnotationRange), visiblePlaceFeatures.count);
    if ([element isKindOfClass:[VMGLPlaceFeatureAccessibilityElement class]])
    {
        visiblePlaceFeatures = [visiblePlaceFeatures sortedArrayUsingComparator:^NSComparisonResult(id <VMGLFeature> _Nonnull featureA, id <VMGLFeature> _Nonnull featureB) {
            CGPoint pointA = [self convertCoordinate:featureA.coordinate toPointToView:self];
            CGPoint pointB = [self convertCoordinate:featureB.coordinate toPointToView:self];
            CGFloat deltaA = hypot(pointA.x - centerPoint.x, pointA.y - centerPoint.y);
            CGFloat deltaB = hypot(pointB.x - centerPoint.x, pointB.y - centerPoint.y);
            return [@(deltaA) compare:@(deltaB)];
        }];
        
        id <VMGLFeature> feature = [(VMGLPlaceFeatureAccessibilityElement *)element feature];
        NSUInteger featureIndex = [visiblePlaceFeatures indexOfObject:feature];
        if (featureIndex == NSNotFound)
        {
            featureIndex = [visiblePlaceFeatures indexOfObjectPassingTest:^BOOL (id <VMGLFeature> _Nonnull visibleFeature, NSUInteger idx, BOOL * _Nonnull stop) {
                return visibleFeature.identifier && ![visibleFeature.identifier isEqual:@0] && [visibleFeature.identifier isEqual:feature.identifier];
            }];
        }
        if (featureIndex == NSNotFound)
        {
            return NSNotFound;
        }
        return visiblePlaceFeatureRange.location + featureIndex;
    }
    
    // Visible road features
    NSArray *visibleRoadFeatures = self.visibleRoadFeatures;
    NSRange visibleRoadFeatureRange = NSMakeRange(NSMaxRange(visiblePlaceFeatureRange), visibleRoadFeatures.count);
    if ([element isKindOfClass:[VMGLRoadFeatureAccessibilityElement class]])
    {
        visibleRoadFeatures = [visibleRoadFeatures sortedArrayUsingComparator:^NSComparisonResult(id <VMGLFeature> _Nonnull featureA, id <VMGLFeature> _Nonnull featureB) {
            CGPoint pointA = [self convertCoordinate:featureA.coordinate toPointToView:self];
            CGPoint pointB = [self convertCoordinate:featureB.coordinate toPointToView:self];
            CGFloat deltaA = hypot(pointA.x - centerPoint.x, pointA.y - centerPoint.y);
            CGFloat deltaB = hypot(pointB.x - centerPoint.x, pointB.y - centerPoint.y);
            return [@(deltaA) compare:@(deltaB)];
        }];
        
        id <VMGLFeature> feature = [(VMGLRoadFeatureAccessibilityElement *)element feature];
        NSUInteger featureIndex = [visibleRoadFeatures indexOfObject:feature];
        if (featureIndex == NSNotFound)
        {
            featureIndex = [visibleRoadFeatures indexOfObjectPassingTest:^BOOL (id <VMGLFeature> _Nonnull visibleFeature, NSUInteger idx, BOOL * _Nonnull stop) {
                return visibleFeature.identifier && ![visibleFeature.identifier isEqual:@0] && [visibleFeature.identifier isEqual:feature.identifier];
            }];
        }
        if (featureIndex == NSNotFound)
        {
            return NSNotFound;
        }
        return visibleRoadFeatureRange.location + featureIndex;
    }
    
    // Attribution button
    NSUInteger attributionButtonIndex = NSMaxRange(visibleRoadFeatureRange);
    if (element == self.attributionButton)
    {
        return attributionButtonIndex;
    }
    
    return NSNotFound;
}

- (VMGLMapViewProxyAccessibilityElement *)mapViewProxyAccessibilityElement
{
    if ( ! _mapViewProxyAccessibilityElement)
    {
        _mapViewProxyAccessibilityElement = [[VMGLMapViewProxyAccessibilityElement alloc] initWithAccessibilityContainer:self];
    }
    return _mapViewProxyAccessibilityElement;
}

- (void)accessibilityIncrement
{
    // Swipe up to zoom out.
    [self accessibilityScaleBy:0.5];
}

- (void)accessibilityDecrement
{
    // Swipe down to zoom in.
    [self accessibilityScaleBy:2];
}

- (void)accessibilityScaleBy:(double)scaleFactor
{
    CGPoint centerPoint = self.contentCenter;
    if (self.userTrackingMode != VMGLUserTrackingModeNone)
    {
        centerPoint = self.userLocationAnnotationViewCenter;
    }
    double newZoom = round(self.zoomLevel) + log2(scaleFactor);
    self.vmglMap.jumpTo(mbgl::CameraOptions()
                        .withZoom(newZoom)
                        .withAnchor(mbgl::ScreenCoordinate { centerPoint.x, centerPoint.y }));
    [self unrotateIfNeededForGesture];

    _accessibilityValueAnnouncementIsPending = YES;
}

#pragma mark - Geography -

+ (NSSet<NSString *> *)keyPathsForValuesAffectingCenterCoordinate
{
    return [NSSet setWithObjects:@"latitude", @"longitude", @"camera", nil];
}

- (void)setCenterCoordinate:(CLLocationCoordinate2D)coordinate animated:(BOOL)animated
{
    MGLLogDebug(@"Setting centerCoordinate: %@ animated: %@", VMGLStringFromCLLocationCoordinate2D(coordinate), VMGLStringFromBOOL(animated));
    [self setCenterCoordinate:coordinate zoomLevel:self.zoomLevel animated:animated];
}

- (void)setCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate
{
    MGLLogDebug(@"Setting centerCoordinate: %@", VMGLStringFromCLLocationCoordinate2D(centerCoordinate));
    [self setCenterCoordinate:centerCoordinate animated:NO];
}

- (CLLocationCoordinate2D)centerCoordinate
{
    return VMGLLocationCoordinate2DFromLatLng(*self.vmglMap.getCameraOptions().center);
}

- (void)setCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate zoomLevel:(double)zoomLevel animated:(BOOL)animated
{
    MGLLogDebug(@"Setting centerCoordinate: %@ zoomLevel: %f animated: %@",
                VMGLStringFromCLLocationCoordinate2D(centerCoordinate),
                zoomLevel,
                VMGLStringFromBOOL(animated));
    [self setCenterCoordinate:centerCoordinate zoomLevel:zoomLevel direction:self.direction animated:animated];
}

- (void)setCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate zoomLevel:(double)zoomLevel direction:(CLLocationDirection)direction animated:(BOOL)animated
{
    MGLLogDebug(@"Setting centerCoordinate: %@ zoomLevel: %f direction: %f animated: %@",
                VMGLStringFromCLLocationCoordinate2D(centerCoordinate),
                zoomLevel,
                direction,
                VMGLStringFromBOOL(animated));
    [self setCenterCoordinate:centerCoordinate zoomLevel:zoomLevel direction:direction animated:animated completionHandler:nil];
}

- (void)setCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate zoomLevel:(double)zoomLevel direction:(CLLocationDirection)direction animated:(BOOL)animated completionHandler:(nullable void (^)(void))completion
{
    MGLLogDebug(@"Setting centerCoordinate: %@ zoomLevel: %f direction: %f animated: %@ completionHandler: %@",
                VMGLStringFromCLLocationCoordinate2D(centerCoordinate),
                zoomLevel,
                direction,
                VMGLStringFromBOOL(animated),
                completion);
    self.userTrackingMode = VMGLUserTrackingModeNone;

    self.cameraChangeReasonBitmask |= VMGLCameraChangeReasonProgrammatic;

    [self _setCenterCoordinate:centerCoordinate edgePadding:self.contentInset zoomLevel:zoomLevel direction:direction duration:animated ? VMGLAnimationDuration : 0 animationTimingFunction:nil completionHandler:completion];
}

- (void)_setCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate edgePadding:(UIEdgeInsets)insets zoomLevel:(double)zoomLevel direction:(CLLocationDirection)direction duration:(NSTimeInterval)duration animationTimingFunction:(nullable CAMediaTimingFunction *)function completionHandler:(nullable void (^)(void))completion
{
    if (!_mbglMap)
    {
        if (completion)
        {
            completion();
        }
        return;
    }
    
    mbgl::CameraOptions cameraOptions;
    cameraOptions.center = VMGLLatLngFromLocationCoordinate2D(centerCoordinate);
    cameraOptions.padding = VMGLEdgeInsetsFromNSEdgeInsets(insets);
    cameraOptions.zoom = zoomLevel;
    if (direction >= 0)
    {
        cameraOptions.bearing = direction;
    }

    mbgl::AnimationOptions animationOptions;
    if (duration)
    {
        animationOptions.duration.emplace(VMGLDurationFromTimeInterval(duration));
        animationOptions.easing.emplace(VMGLUnitBezierForMediaTimingFunction(function));
    }
    
    dispatch_block_t pendingCompletion;
    
    if (completion)
    {
        __weak __typeof__(self) weakSelf = self;
        
        pendingCompletion = ^{
            if (![weakSelf scheduleTransitionCompletion:completion])
            {
                completion();
            }
        };
        
        animationOptions.transitionFinishFn = [pendingCompletion]() {
            // Must run asynchronously after the transition is completely over.
            // Otherwise, a call to -setCenterCoordinate: within the completion
            // handler would reenter the completion handler’s caller.

            dispatch_async(dispatch_get_main_queue(), pendingCompletion);
        };
    }
    
    VMGLMapCamera *camera = [self cameraForCameraOptions:cameraOptions];
    if ([self.camera isEqualToMapCamera:camera] && UIEdgeInsetsEqualToEdgeInsets(_contentInset, insets))
    {
        if (pendingCompletion)
        {
            [self animateWithDelay:duration animations:pendingCompletion];
        }
        return;
    }
    
    [self cancelTransitions];

    self.cameraChangeReasonBitmask |= VMGLCameraChangeReasonProgrammatic;

    self.vmglMap.easeTo(cameraOptions, animationOptions);
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingZoomLevel
{
    return [NSSet setWithObject:@"camera"];
}

- (double)zoomLevel
{
    return *self.vmglMap.getCameraOptions().zoom;
}

- (void)setZoomLevel:(double)zoomLevel
{
    MGLLogDebug(@"Setting zoomLevel: %f", zoomLevel);
    [self setZoomLevel:zoomLevel animated:NO];
}

- (void)setZoomLevel:(double)zoomLevel animated:(BOOL)animated
{
    MGLLogDebug(@"Setting zoomLevel: %f animated: %@", zoomLevel, VMGLStringFromBOOL(animated));
    if (zoomLevel == self.zoomLevel) return;
    [self cancelTransitions];

    self.cameraChangeReasonBitmask |= VMGLCameraChangeReasonProgrammatic;

    CGFloat duration = animated ? VMGLAnimationDuration : 0;

    self.vmglMap.easeTo(mbgl::CameraOptions()
                            .withZoom(zoomLevel), VMGLDurationFromTimeInterval(duration));
}

- (void)setMinimumZoomLevel:(double)minimumZoomLevel
{
    MGLLogDebug(@"Setting minimumZoomLevel: %f", minimumZoomLevel);
    self.vmglMap.setBounds(mbgl::BoundOptions().withMinZoom(minimumZoomLevel));
}

- (double)minimumZoomLevel
{
    return *self.vmglMap.getBounds().minZoom;
}

- (void)setMaximumZoomLevel:(double)maximumZoomLevel
{
    MGLLogDebug(@"Setting maximumZoomLevel: %f", maximumZoomLevel);
    self.vmglMap.setBounds(mbgl::BoundOptions().withMaxZoom(maximumZoomLevel));
}

- (double)maximumZoomLevel
{
    return *self.vmglMap.getBounds().maxZoom;
}

- (CGFloat)minimumPitch
{
    return *self.vmglMap.getBounds().minPitch;
}

- (void)setMinimumPitch:(CGFloat)minimumPitch
{
    MGLLogDebug(@"Setting minimumPitch: %f", minimumPitch);
    self.vmglMap.setBounds(mbgl::BoundOptions().withMinPitch(minimumPitch));
}

- (CGFloat)maximumPitch
{
    return *self.vmglMap.getBounds().maxPitch;
}

- (void)setMaximumPitch:(CGFloat)maximumPitch
{
    MGLLogDebug(@"Setting maximumPitch: %f", maximumPitch);
    self.vmglMap.setBounds(mbgl::BoundOptions().withMaxPitch(maximumPitch));
}

- (VMGLCoordinateBounds)visibleCoordinateBounds
{
    return [self convertRect:self.bounds toCoordinateBoundsFromView:self];
}

- (void)setVisibleCoordinateBounds:(VMGLCoordinateBounds)bounds
{
    [self setVisibleCoordinateBounds:bounds animated:NO];
}

- (void)setVisibleCoordinateBounds:(VMGLCoordinateBounds)bounds animated:(BOOL)animated
{
    [self setVisibleCoordinateBounds:bounds edgePadding:UIEdgeInsetsZero animated:animated completionHandler:nil];
}

- (void)setVisibleCoordinateBounds:(VMGLCoordinateBounds)bounds edgePadding:(UIEdgeInsets)insets animated:(BOOL)animated
{
    [self setVisibleCoordinateBounds:bounds edgePadding:insets animated:animated completionHandler:nil];
}

- (void)setVisibleCoordinateBounds:(VMGLCoordinateBounds)bounds edgePadding:(UIEdgeInsets)insets animated:(BOOL)animated completionHandler:(nullable void (^)(void))completion
{
    MGLLogDebug(@"Setting visibleCoordinateBounds: %@ edgePadding: %@ animated: %@",
                VMGLStringFromCoordinateBounds(bounds),
                NSStringFromUIEdgeInsets(insets),
                VMGLStringFromBOOL(animated));
    CLLocationCoordinate2D coordinates[] = {
        {bounds.ne.latitude, bounds.sw.longitude},
        bounds.sw,
        {bounds.sw.latitude, bounds.ne.longitude},
        bounds.ne,
    };
    [self setVisibleCoordinates:coordinates
                          count:sizeof(coordinates) / sizeof(coordinates[0])
                    edgePadding:insets
                      direction:self.direction
                       duration:animated ? VMGLAnimationDuration : 0
        animationTimingFunction:nil
              completionHandler:completion];
}

- (void)setVisibleCoordinates:(const CLLocationCoordinate2D *)coordinates count:(NSUInteger)count edgePadding:(UIEdgeInsets)insets animated:(BOOL)animated
{
    MGLLogDebug(@"Setting: %lu coordinates edgePadding: %@ animated: %@",
                count,
                NSStringFromUIEdgeInsets(insets),
                VMGLStringFromBOOL(animated));
    [self setVisibleCoordinates:coordinates count:count edgePadding:insets direction:self.direction duration:animated ? VMGLAnimationDuration : 0 animationTimingFunction:nil];
}

- (void)setVisibleCoordinates:(const CLLocationCoordinate2D *)coordinates count:(NSUInteger)count edgePadding:(UIEdgeInsets)insets direction:(CLLocationDirection)direction duration:(NSTimeInterval)duration animationTimingFunction:(nullable CAMediaTimingFunction *)function {
    MGLLogDebug(@"Setting: %lu coordinates edgePadding: %@ direction: %f duration: %f animationTimingFunction: %@",
                count,
                NSStringFromUIEdgeInsets(insets),
                direction,
                duration,
                function);
    [self setVisibleCoordinates:coordinates count:count edgePadding:insets direction:direction duration:duration animationTimingFunction:function completionHandler:NULL];
}

- (void)setVisibleCoordinates:(const CLLocationCoordinate2D *)coordinates count:(NSUInteger)count edgePadding:(UIEdgeInsets)insets direction:(CLLocationDirection)direction duration:(NSTimeInterval)duration animationTimingFunction:(nullable CAMediaTimingFunction *)function completionHandler:(nullable void (^)(void))completion
{
    MGLLogDebug(@"Setting: %lu coordinates edgePadding: %@ direction: %f duration: %f animationTimingFunction: %@ completionHandler: %@", count, NSStringFromUIEdgeInsets(insets), direction, duration, function, completion);
    self.userTrackingMode = VMGLUserTrackingModeNone;

    self.cameraChangeReasonBitmask |= VMGLCameraChangeReasonProgrammatic;

    [self _setVisibleCoordinates:coordinates count:count edgePadding:insets direction:direction duration:duration animationTimingFunction:function completionHandler:completion];
}

- (void)_setVisibleCoordinates:(const CLLocationCoordinate2D *)coordinates count:(NSUInteger)count edgePadding:(UIEdgeInsets)insets direction:(CLLocationDirection)direction duration:(NSTimeInterval)duration animationTimingFunction:(nullable CAMediaTimingFunction *)function completionHandler:(nullable void (^)(void))completion
{
    if (!_mbglMap)
    {
        if (completion)
        {
            completion();
        }
        return;
    }
    
    mbgl::EdgeInsets padding = VMGLEdgeInsetsFromNSEdgeInsets(insets);
    padding += VMGLEdgeInsetsFromNSEdgeInsets(self.contentInset);
    std::vector<mbgl::LatLng> latLngs;
    latLngs.reserve(count);
    for (NSUInteger i = 0; i < count; i++)
    {
        latLngs.push_back({coordinates[i].latitude, coordinates[i].longitude});
    }
    
    CLLocationDirection cameraDirection = direction >= 0 ? direction : self.direction;

    mbgl::CameraOptions cameraOptions = self.vmglMap.cameraForLatLngs(latLngs, padding, cameraDirection);

    mbgl::AnimationOptions animationOptions;
    if (duration > 0)
    {
        animationOptions.duration.emplace(VMGLDurationFromTimeInterval(duration));
        animationOptions.easing.emplace(VMGLUnitBezierForMediaTimingFunction(function));
    }
    
    dispatch_block_t pendingCompletion;
    
    if (completion)
    {
        __weak __typeof__(self) weakSelf = self;
        
        pendingCompletion = ^{
            if (![weakSelf scheduleTransitionCompletion:completion])
            {
                completion();
            }
        };

        animationOptions.transitionFinishFn = [pendingCompletion]() {
            dispatch_async(dispatch_get_main_queue(), pendingCompletion);
        };
    }

    // Padding is baked in adjusted camera center (in cameraForLatLngs) and
    // cameraOptions.padding at this point is (0, 0, 0, 0) and we don't need to
    // check if cameraOptions.contentInsets are equal to contentInsets.
    VMGLMapCamera *camera = [self cameraForCameraOptions:cameraOptions];
    if ([self.camera isEqualToMapCamera:camera])
    {
        if (pendingCompletion)
        {
            [self animateWithDelay:duration animations:pendingCompletion];
        }
        return;
    }
    
    [self willChangeValueForKey:@"visibleCoordinateBounds"];
    [self cancelTransitions];

    self.cameraChangeReasonBitmask |= VMGLCameraChangeReasonProgrammatic;

    self.vmglMap.easeTo(cameraOptions, animationOptions);
    [self didChangeValueForKey:@"visibleCoordinateBounds"];
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingDirection
{
    return [NSSet setWithObject:@"camera"];
}

- (CLLocationDirection)direction
{
    return mbgl::util::wrap(*self.vmglMap.getCameraOptions().bearing, 0., 360.);
}

- (void)setDirection:(CLLocationDirection)direction animated:(BOOL)animated
{
    MGLLogDebug(@"Setting direction: %f animated: %@", direction, VMGLStringFromBOOL(animated));
    if ( ! animated && ! self.rotationAllowed) return;

    if (self.userTrackingMode == VMGLUserTrackingModeFollowWithHeading ||
        self.userTrackingMode == VMGLUserTrackingModeFollowWithCourse)
    {
        self.userTrackingMode = VMGLUserTrackingModeFollow;
    }

    [self _setDirection:direction animated:animated];
}

- (void)_setDirection:(CLLocationDirection)direction animated:(BOOL)animated
{
    if (!_mbglMap)
    {
        return;
    }
    
    if (direction == self.direction) return;
    [self cancelTransitions];

    CGFloat duration = animated ? VMGLAnimationDuration : 0;

    self.cameraChangeReasonBitmask |= VMGLCameraChangeReasonProgrammatic;

    if (self.userTrackingMode == VMGLUserTrackingModeNone)
    {
        self.vmglMap.easeTo(mbgl::CameraOptions().withBearing(direction),
                            VMGLDurationFromTimeInterval(duration));
    }
    else
    {
        CGPoint anchor = self.userLocationAnnotationViewCenter;
        self.vmglMap.easeTo(mbgl::CameraOptions()
                                .withBearing(direction)
                                .withAnchor(mbgl::ScreenCoordinate { anchor.x, anchor.y }),
                            VMGLDurationFromTimeInterval(duration));
    }
}

- (void)setDirection:(CLLocationDirection)direction
{
    MGLLogDebug(@"Setting direction: %f", direction);
    [self setDirection:direction animated:NO];
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingPitch
{
    return [NSSet setWithObject:@"camera"];
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingCamera
{
    return [NSSet setWithObjects:@"longitude", @"latitude", @"centerCoordinate", @"zoomLevel", @"direction", nil];
}

- (UIEdgeInsets)cameraEdgeInsets {
    mbgl::CameraOptions cameraOptions = self.vmglMap.getCameraOptions();
    return NSEdgeInsetsFromMGLEdgeInsets(cameraOptions.padding.value_or(mbgl::EdgeInsets()));
}

- (VMGLMapCamera *)camera
{
    if (!_mbglMap)
    {
        NSAssert(self.terminated, @"_mbglMap should only be unavailable during app termination");
        return self.residualCamera;
    }
    
    return [self cameraForCameraOptions:self.vmglMap.getCameraOptions()];
}

- (void)setCamera:(VMGLMapCamera *)camera
{
    MGLLogDebug(@"Setting camera: %@", camera);
    [self setCamera:camera animated:NO];
}

- (void)setCamera:(VMGLMapCamera *)camera animated:(BOOL)animated
{
    MGLLogDebug(@"Setting camera: %@ animated: %@", camera, VMGLStringFromBOOL(animated));
    [self setCamera:camera withDuration:animated ? VMGLAnimationDuration : 0 animationTimingFunction:nil];
}

- (void)setCamera:(VMGLMapCamera *)camera withDuration:(NSTimeInterval)duration animationTimingFunction:(nullable CAMediaTimingFunction *)function
{
    MGLLogDebug(@"Setting camera: %@ duration: %f animationTimingFunction: %@", camera, duration, function);
    [self setCamera:camera withDuration:duration animationTimingFunction:function completionHandler:nil];
}

- (void)setCamera:(VMGLMapCamera *)camera withDuration:(NSTimeInterval)duration animationTimingFunction:(nullable CAMediaTimingFunction *)function completionHandler:(nullable void (^)(void))completion
{
    MGLLogDebug(@"Setting camera: %@ duration: %f animationTimingFunction: %@ completionHandler: %@", camera, duration, function, completion);
    [self setCamera:camera withDuration:duration animationTimingFunction:function edgePadding:UIEdgeInsetsZero completionHandler:completion];
}

- (void)setCamera:(VMGLMapCamera *)camera withDuration:(NSTimeInterval)duration animationTimingFunction:(nullable CAMediaTimingFunction *)function edgePadding:(UIEdgeInsets)edgePadding completionHandler:(nullable void (^)(void))completion {
    if (!_mbglMap)
    {
        if (completion)
        {
            completion();
        }
        return;
    }

    MGLLogDebug(@"Setting camera: %@ duration: %f animationTimingFunction: %@ edgePadding: %@ completionHandler: %@", camera, duration, function, NSStringFromUIEdgeInsets(edgePadding), completion);
    
    edgePadding = MGLEdgeInsetsInsetEdgeInset(edgePadding, self.contentInset);

    mbgl::AnimationOptions animationOptions;
    if (duration > 0)
    {
        animationOptions.duration.emplace(VMGLDurationFromTimeInterval(duration));
        animationOptions.easing.emplace(VMGLUnitBezierForMediaTimingFunction(function));
    }
    
    dispatch_block_t pendingCompletion;
    
    if (completion)
    {
        __weak __typeof__(self) weakSelf = self;
        
        pendingCompletion = ^{
            if (![weakSelf scheduleTransitionCompletion:completion])
            {
                completion();
            }
        };

        animationOptions.transitionFinishFn = [pendingCompletion]() {
            dispatch_async(dispatch_get_main_queue(), pendingCompletion);
        };
    }
    
    if ([self.camera isEqualToMapCamera:camera] && UIEdgeInsetsEqualToEdgeInsets(_contentInset, edgePadding))
    {
        if (pendingCompletion)
        {
            [self animateWithDelay:duration animations:pendingCompletion];
        }
        return;
    }

    [self willChangeValueForKey:@"camera"];
    [self cancelTransitions];

    self.cameraChangeReasonBitmask |= VMGLCameraChangeReasonProgrammatic;

    mbgl::CameraOptions cameraOptions = [self cameraOptionsObjectForAnimatingToCamera:camera edgePadding:edgePadding];
    self.vmglMap.easeTo(cameraOptions, animationOptions);
    [self didChangeValueForKey:@"camera"];
}

- (void)flyToCamera:(VMGLMapCamera *)camera completionHandler:(nullable void (^)(void))completion
{
    MGLLogDebug(@"Setting flyToCamera: %@ completionHandler: %@", camera, completion);
    [self flyToCamera:camera withDuration:-1 completionHandler:completion];
}

- (void)flyToCamera:(VMGLMapCamera *)camera withDuration:(NSTimeInterval)duration completionHandler:(nullable void (^)(void))completion
{
    MGLLogDebug(@"Setting flyToCamera: %@ withDuration: %f completionHandler: %@", camera, duration, completion);
    [self flyToCamera:camera withDuration:duration peakAltitude:-1 completionHandler:completion];
}

- (void)flyToCamera:(VMGLMapCamera *)camera withDuration:(NSTimeInterval)duration peakAltitude:(CLLocationDistance)peakAltitude completionHandler:(nullable void (^)(void))completion
{
    MGLLogDebug(@"Setting flyToCamera: %@ withDuration: %f peakAltitude: %f completionHandler: %@", camera, duration, peakAltitude, completion);
    [self _flyToCamera:camera edgePadding:self.contentInset withDuration:duration peakAltitude:peakAltitude completionHandler:completion];
}

- (void)_flyToCamera:(VMGLMapCamera *)camera edgePadding:(UIEdgeInsets)insets withDuration:(NSTimeInterval)duration peakAltitude:(CLLocationDistance)peakAltitude completionHandler:(nullable void (^)(void))completion
{
    if (!_mbglMap)
    {
        if (completion)
        {
            completion();
        }
        return;
    }

    mbgl::AnimationOptions animationOptions;
    if (duration >= 0)
    {
        animationOptions.duration = VMGLDurationFromTimeInterval(duration);
    }
    if (peakAltitude >= 0)
    {
        CLLocationDegrees peakLatitude = (self.centerCoordinate.latitude + camera.centerCoordinate.latitude) / 2;
        CLLocationDegrees peakPitch = (self.camera.pitch + camera.pitch) / 2;
        animationOptions.minZoom = VMGLZoomLevelForAltitude(peakAltitude, peakPitch,
                                                           peakLatitude, self.frame.size);
    }
    
    dispatch_block_t pendingCompletion;
    
    if (completion)
    {
        __weak __typeof__(self) weakSelf = self;
        
        pendingCompletion = ^{
            if (![weakSelf scheduleTransitionCompletion:completion])
            {
                completion();
            }
        };

        animationOptions.transitionFinishFn = [pendingCompletion]() {
            dispatch_async(dispatch_get_main_queue(), pendingCompletion);
        };
    }
    
    if ([self.camera isEqualToMapCamera:camera] && UIEdgeInsetsEqualToEdgeInsets(_contentInset, insets))
    {
        if (pendingCompletion)
        {
            [self animateWithDelay:duration animations:pendingCompletion];
        }
        return;
    }

    [self willChangeValueForKey:@"camera"];
    [self cancelTransitions];

    self.cameraChangeReasonBitmask |= VMGLCameraChangeReasonProgrammatic;

    mbgl::CameraOptions cameraOptions = [self cameraOptionsObjectForAnimatingToCamera:camera edgePadding:insets];
    self.vmglMap.flyTo(cameraOptions, animationOptions);
    [self didChangeValueForKey:@"camera"];
}

- (void)cancelTransitions {
    if (!_mbglMap)
    {
        return;
    }
    self.cameraChangeReasonBitmask |= VMGLCameraChangeReasonTransitionCancelled;
    self.vmglMap.cancelTransitions();
    self.cameraChangeReasonBitmask &= ~VMGLCameraChangeReasonTransitionCancelled;
}

- (VMGLMapCamera *)cameraThatFitsCoordinateBounds:(VMGLCoordinateBounds)bounds
{
    return [self cameraThatFitsCoordinateBounds:bounds edgePadding:UIEdgeInsetsZero];
}

- (VMGLMapCamera *)cameraThatFitsCoordinateBounds:(VMGLCoordinateBounds)bounds edgePadding:(UIEdgeInsets)insets
{
    if (!_mbglMap)
    {
        return self.residualCamera;
    }

    mbgl::EdgeInsets padding = VMGLEdgeInsetsFromNSEdgeInsets(insets);
    padding += VMGLEdgeInsetsFromNSEdgeInsets(self.contentInset);
    mbgl::CameraOptions cameraOptions = self.vmglMap.cameraForLatLngBounds(VMGLLatLngBoundsFromCoordinateBounds(bounds), padding);
    return [self cameraForCameraOptions:cameraOptions];
}

- (VMGLMapCamera *)camera:(VMGLMapCamera *)camera fittingCoordinateBounds:(VMGLCoordinateBounds)bounds edgePadding:(UIEdgeInsets)insets
{
    if (!_mbglMap)
    {
        return self.residualCamera;
    }

    mbgl::EdgeInsets padding = VMGLEdgeInsetsFromNSEdgeInsets(insets);
    padding += VMGLEdgeInsetsFromNSEdgeInsets(self.contentInset);
    
    VMGLMapCamera *currentCamera = self.camera;
    CGFloat pitch = camera.pitch < 0 ? currentCamera.pitch : camera.pitch;
    CLLocationDirection direction = camera.heading < 0 ? currentCamera.heading : camera.heading;
    
    mbgl::CameraOptions cameraOptions = self.vmglMap.cameraForLatLngBounds(VMGLLatLngBoundsFromCoordinateBounds(bounds), padding, direction, pitch);
    return [self cameraForCameraOptions:cameraOptions];
}

- (VMGLMapCamera *)camera:(VMGLMapCamera *)camera fittingShape:(VMGLShape *)shape edgePadding:(UIEdgeInsets)insets {
    if (!_mbglMap)
    {
        return self.residualCamera;
    }

    mbgl::EdgeInsets padding = VMGLEdgeInsetsFromNSEdgeInsets(insets);
    padding += VMGLEdgeInsetsFromNSEdgeInsets(self.contentInset);
    
    VMGLMapCamera *currentCamera = self.camera;
    CGFloat pitch = camera.pitch < 0 ? currentCamera.pitch : camera.pitch;
    CLLocationDirection direction = camera.heading < 0 ? currentCamera.heading : camera.heading;
    
    mbgl::CameraOptions cameraOptions = self.vmglMap.cameraForGeometry([shape geometryObject], padding, direction, pitch);
    
    return [self cameraForCameraOptions: cameraOptions];
}

- (VMGLMapCamera *)cameraThatFitsShape:(VMGLShape *)shape direction:(CLLocationDirection)direction edgePadding:(UIEdgeInsets)insets {
    if (!_mbglMap)
    {
        return self.residualCamera;
    }

    mbgl::EdgeInsets padding = VMGLEdgeInsetsFromNSEdgeInsets(insets);
    padding += VMGLEdgeInsetsFromNSEdgeInsets(self.contentInset);
    
    mbgl::CameraOptions cameraOptions = self.vmglMap.cameraForGeometry([shape geometryObject], padding, direction);
    
    return [self cameraForCameraOptions:cameraOptions];
}

- (VMGLMapCamera *)cameraForCameraOptions:(const mbgl::CameraOptions &)cameraOptions
{
    if (!_mbglMap)
    {
        return self.residualCamera;
    }

    mbgl::CameraOptions mapCamera = self.vmglMap.getCameraOptions();
    CLLocationCoordinate2D centerCoordinate = VMGLLocationCoordinate2DFromLatLng(cameraOptions.center ? *cameraOptions.center : *mapCamera.center);
    double zoomLevel = cameraOptions.zoom ? *cameraOptions.zoom : self.zoomLevel;
    CLLocationDirection direction = cameraOptions.bearing ? mbgl::util::wrap(*cameraOptions.bearing, 0., 360.) : self.direction;
    CGFloat pitch = cameraOptions.pitch ? *cameraOptions.pitch : *mapCamera.pitch;
    CLLocationDistance altitude = MGLAltitudeForZoomLevel(zoomLevel, pitch, centerCoordinate.latitude, self.frame.size);
    return [VMGLMapCamera cameraLookingAtCenterCoordinate:centerCoordinate altitude:altitude pitch:pitch heading:direction];
}

/// Returns a CameraOptions object that specifies parameters for animating to
/// the given camera.
- (mbgl::CameraOptions)cameraOptionsObjectForAnimatingToCamera:(VMGLMapCamera *)camera edgePadding:(UIEdgeInsets)insets
{
    mbgl::CameraOptions options;
    if (CLLocationCoordinate2DIsValid(camera.centerCoordinate))
    {
        options.center = VMGLLatLngFromLocationCoordinate2D(camera.centerCoordinate);
    }
    options.padding = VMGLEdgeInsetsFromNSEdgeInsets(insets);
    options.zoom = VMGLZoomLevelForAltitude(camera.altitude, camera.pitch,
                                           camera.centerCoordinate.latitude,
                                           self.frame.size);
    if (camera.heading >= 0)
    {
        options.bearing = camera.heading;
    }
    if (camera.pitch >= 0)
    {
        options.pitch = camera.pitch;
    }
    return options;
}

- (CLLocationCoordinate2D)convertPoint:(CGPoint)point toCoordinateFromView:(nullable UIView *)view
{
    return VMGLLocationCoordinate2DFromLatLng([self convertPoint:point toLatLngFromView:view]);
}

/// Converts a point in the view’s coordinate system to a geographic coordinate.
- (mbgl::LatLng)convertPoint:(CGPoint)point toLatLngFromView:(nullable UIView *)view
{
    CGPoint convertedPoint = [self convertPoint:point fromView:view];
    return self.vmglMap.latLngForPixel(mbgl::ScreenCoordinate(convertedPoint.x, convertedPoint.y)).wrapped();
}

- (CGPoint)convertCoordinate:(CLLocationCoordinate2D)coordinate toPointToView:(nullable UIView *)view
{
    if ( ! CLLocationCoordinate2DIsValid(coordinate))
    {
        return CGPointMake(NAN, NAN);
    }
    return [self convertLatLng:VMGLLatLngFromLocationCoordinate2D(coordinate) toPointToView:view];
}

/// Converts a geographic coordinate to a point in the view’s coordinate system.
- (CGPoint)convertLatLng:(mbgl::LatLng)latLng toPointToView:(nullable UIView *)view
{
    mbgl::ScreenCoordinate pixel = self.vmglMap.pixelForLatLng(latLng);
    return [self convertPoint:CGPointMake(pixel.x, pixel.y) toView:view];
}

- (VMGLCoordinateBounds)convertRect:(CGRect)rect toCoordinateBoundsFromView:(nullable UIView *)view
{
    return VMGLCoordinateBoundsFromLatLngBounds([self convertRect:rect toLatLngBoundsFromView:view]);
}

- (CGRect)convertCoordinateBounds:(VMGLCoordinateBounds)bounds toRectToView:(nullable UIView *)view
{
    return [self convertLatLngBounds:VMGLLatLngBoundsFromCoordinateBounds(bounds) toRectToView:view];
}

/// Converts a geographic bounding box to a rectangle in the view’s coordinate
/// system.
- (CGRect)convertLatLngBounds:(mbgl::LatLngBounds)bounds toRectToView:(nullable UIView *)view {
    auto northwest = bounds.northwest();
    auto northeast = bounds.northeast();
    auto southwest = bounds.southwest();
    auto southeast = bounds.southeast();

    auto center = [self convertPoint:{ CGRectGetMidX(view.bounds), CGRectGetMidY(view.bounds) } toLatLngFromView:view];

    // Extend bounds to account for the antimeridian
    northwest.unwrapForShortestPath(center);
    northeast.unwrapForShortestPath(center);
    southwest.unwrapForShortestPath(center);
    southeast.unwrapForShortestPath(center);

    auto correctedLatLngBounds = mbgl::LatLngBounds::empty();
    correctedLatLngBounds.extend(northwest);
    correctedLatLngBounds.extend(northeast);
    correctedLatLngBounds.extend(southwest);
    correctedLatLngBounds.extend(southeast);
    
    CGRect rect = { [self convertLatLng:correctedLatLngBounds.southwest() toPointToView:view], CGSizeZero };
    rect = VMGLExtendRect(rect, [self convertLatLng:correctedLatLngBounds.northeast() toPointToView:view]);
    return rect;
}

/// Converts a rectangle in the given view’s coordinate system to a geographic
/// bounding box.
- (mbgl::LatLngBounds)convertRect:(CGRect)rect toLatLngBoundsFromView:(nullable UIView *)view
{
    auto bounds = mbgl::LatLngBounds::empty();
    auto topLeft = [self convertPoint:{ CGRectGetMinX(rect), CGRectGetMinY(rect) } toLatLngFromView:view];
    auto topRight = [self convertPoint:{ CGRectGetMaxX(rect), CGRectGetMinY(rect) } toLatLngFromView:view];
    auto bottomRight = [self convertPoint:{ CGRectGetMaxX(rect), CGRectGetMaxY(rect) } toLatLngFromView:view];
    auto bottomLeft = [self convertPoint:{ CGRectGetMinX(rect), CGRectGetMaxY(rect) } toLatLngFromView:view];
    
    // If the bounds straddles the antimeridian, unwrap it so that one side
    // extends beyond ±180° longitude.
    auto center = [self convertPoint:{ CGRectGetMidX(rect), CGRectGetMidY(rect) } toLatLngFromView:view];
    topLeft.unwrapForShortestPath(center);
    topRight.unwrapForShortestPath(center);
    bottomRight.unwrapForShortestPath(center);
    bottomLeft.unwrapForShortestPath(center);
    
    bounds.extend(topLeft);
    bounds.extend(topRight);
    bounds.extend(bottomRight);
    bounds.extend(bottomLeft);

    return bounds;
}

- (CLLocationDistance)metersPerPointAtLatitude:(CLLocationDegrees)latitude
{
    return mbgl::Projection::getMetersPerPixelAtLatitude(latitude, self.zoomLevel);
}

- (CLLocationDistance)metersPerPointAtLatitude:(CLLocationDegrees)latitude zoomLevel:(double)zoomLevel
{
    return mbgl::Projection::getMetersPerPixelAtLatitude(latitude, zoomLevel);
}

- (VMGLMapProjection*)mapProjection {
    return [[VMGLMapProjection alloc] initWithMapView:self];
}

#pragma mark - Camera Change Reason -

- (void)resetCameraChangeReason
{
    self.cameraChangeReasonBitmask = VMGLCameraChangeReasonNone;
}

#pragma mark - Annotations -

- (nullable NSArray<id <VMGLAnnotation>> *)annotations
{
    if (_annotationContextsByAnnotationTag.empty())
    {
        return nil;
    }

    // Map all the annotation tags to the annotations themselves.
    std::vector<id <VMGLAnnotation>> annotations;
    std::transform(_annotationContextsByAnnotationTag.begin(),
                   _annotationContextsByAnnotationTag.end(),
                   std::back_inserter(annotations),
                   ^ id <VMGLAnnotation> (const std::pair<VMGLAnnotationTag, VMGLAnnotationContext> &pair)
    {
        return pair.second.annotation;
    });

    annotations.erase(std::remove_if(annotations.begin(), annotations.end(),
                                     [](const id <VMGLAnnotation> annotation) { return annotation == nullptr; }),
                      annotations.end());

    return [NSArray arrayWithObjects:&annotations[0] count:annotations.size()];
}

- (nullable NSArray<id <VMGLAnnotation>> *)visibleAnnotations
{
    return [self visibleAnnotationsInRect:self.bounds];
}

- (nullable NSArray<id <VMGLAnnotation>> *)visibleAnnotationsInRect:(CGRect)rect
{
    if (_annotationContextsByAnnotationTag.empty())
    {
        return nil;
    }

    std::vector<VMGLAnnotationTag> annotationTags = [self annotationTagsInRect:rect];
    std::vector<VMGLAnnotationTag> shapeAnnotationTags = [self shapeAnnotationTagsInRect:rect];
    
    if (shapeAnnotationTags.size()) {
        annotationTags.insert(annotationTags.end(), shapeAnnotationTags.begin(), shapeAnnotationTags.end());
    }
    
    if (annotationTags.size())
    {
        NSMutableArray *annotations = [NSMutableArray arrayWithCapacity:annotationTags.size()];

        for (auto const& annotationTag: annotationTags)
        {
            if (!_annotationContextsByAnnotationTag.count(annotationTag) ||
                annotationTag == VMGLAnnotationTagNotFound)
            {
                continue;
            }

            VMGLAnnotationContext annotationContext = _annotationContextsByAnnotationTag.at(annotationTag);
            MGLAssert(annotationContext.annotation, @"Missing annotation for tag %llu.", annotationTag);
            if (annotationContext.annotation)
            {
                [annotations addObject:annotationContext.annotation];
            }
        }

        return [annotations copy];
    }

    return nil;
}

/// Returns the annotation assigned the given tag. Cheap.
- (id <VMGLAnnotation>)annotationWithTag:(VMGLAnnotationTag)tag
{
    if ( ! _annotationContextsByAnnotationTag.count(tag) ||
        tag == VMGLAnnotationTagNotFound) {
        return nil;
    }

    VMGLAnnotationContext &annotationContext = _annotationContextsByAnnotationTag.at(tag);
    return annotationContext.annotation;
}

/// Returns the annotation tag assigned to the given annotation.
- (VMGLAnnotationTag)annotationTagForAnnotation:(id <VMGLAnnotation>)annotation
{
    if ( ! annotation || annotation == self.userLocation
        || _annotationTagsByAnnotation.count(annotation) == 0)
    {
        return VMGLAnnotationTagNotFound;
    }

    return _annotationTagsByAnnotation.at(annotation);
}

- (void)addAnnotation:(id <VMGLAnnotation>)annotation
{
    MGLLogDebug(@"Adding annotation: %@", annotation);
    if ( ! annotation) return;

    // The core bulk add API is efficient with respect to indexing and
    // screen refreshes, thus we should defer to it even for individual adds.
    //
    [self addAnnotations:@[ annotation ]];
}

- (void)addAnnotations:(NSArray<id <VMGLAnnotation>> *)annotations
{
    MGLLogDebug(@"Adding: %lu annotations", annotations.count);
    if ( ! annotations) return;
    [self willChangeValueForKey:@"annotations"];

    NSMutableDictionary *annotationImagesForAnnotation = [NSMutableDictionary dictionary];
    NSMutableDictionary *annotationViewsForAnnotation = [NSMutableDictionary dictionary];

    BOOL delegateImplementsViewForAnnotation = [self.delegate respondsToSelector:@selector(mapView:viewForAnnotation:)];
    BOOL delegateImplementsImageForPoint = [self.delegate respondsToSelector:@selector(mapView:imageForAnnotation:)];

    NSMutableArray *newAnnotationViews = [[NSMutableArray alloc] initWithCapacity:annotations.count];

    for (id <VMGLAnnotation> annotation in annotations)
    {
        MGLAssert([annotation conformsToProtocol:@protocol(VMGLAnnotation)], @"annotation should conform to MGLAnnotation");

        // adding the same annotation object twice is a no-op
        if (_annotationTagsByAnnotation.count(annotation) != 0)
        {
            continue;
        }

        if ([annotation isKindOfClass:[VMGLMultiPoint class]])
        {
            // The polyline or polygon knows how to style itself (with the map view’s help).
            VMGLMultiPoint *multiPoint = (VMGLMultiPoint *)annotation;
            if (!multiPoint.pointCount) {
                continue;
            }

            _isChangingAnnotationLayers = YES;
            VMGLAnnotationTag annotationTag = self.vmglMap.addAnnotation([multiPoint annotationObjectWithDelegate:self]);
            VMGLAnnotationContext context;
            context.annotation = annotation;
            _annotationContextsByAnnotationTag[annotationTag] = context;
            _annotationTagsByAnnotation[annotation] = annotationTag;

            [(NSObject *)annotation addObserver:self forKeyPath:@"coordinates" options:0 context:(void *)(NSUInteger)annotationTag];
        }
        else if ( ! [annotation isKindOfClass:[VMGLMultiPolyline class]]
                 && ![annotation isKindOfClass:[VMGLMultiPolygon class]]
                 && ![annotation isKindOfClass:[VMGLShapeCollection class]]
                 && ![annotation isKindOfClass:[VMGLPointCollection class]])
        {
            VMGLAnnotationView *annotationView;
            NSString *symbolName;
            NSValue *annotationValue = [NSValue valueWithNonretainedObject:annotation];

            if (delegateImplementsViewForAnnotation)
            {
                annotationView = [self annotationViewForAnnotation:annotation];
                if (annotationView)
                {
                    annotationViewsForAnnotation[annotationValue] = annotationView;
                    annotationView.annotation = annotation;
                    annotationView.center = VMGLPointRounded([self convertCoordinate:annotation.coordinate toPointToView:self]);
                    [newAnnotationViews addObject:annotationView];

                    VMGLAnnotationImage *annotationImage = self.invisibleAnnotationImage;
                    symbolName = annotationImage.styleIconIdentifier;
                    annotationImagesForAnnotation[annotationValue] = annotationImage;
                    if ( ! self.annotationImagesByIdentifier[annotationImage.reuseIdentifier])
                    {
                        [self installAnnotationImage:annotationImage];
                    }
                }
            }

            if ( ! annotationView) {
                VMGLAnnotationImage *annotationImage;

                if (delegateImplementsImageForPoint)
                {
                    annotationImage = [self.delegate mapView:self imageForAnnotation:annotation];
                }
                if ( ! annotationImage)
                {
                    annotationImage = [self dequeueReusableAnnotationImageWithIdentifier:VMGLDefaultStyleMarkerSymbolName];
                }
                if ( ! annotationImage)
                {
                    annotationImage = self.defaultAnnotationImage;
                }

                symbolName = annotationImage.styleIconIdentifier;

                if ( ! symbolName)
                {
                    symbolName = [VMGLAnnotationSpritePrefix stringByAppendingString:annotationImage.reuseIdentifier];
                    annotationImage.styleIconIdentifier = symbolName;
                }
                if ( ! self.annotationImagesByIdentifier[annotationImage.reuseIdentifier])
                {
                    [self installAnnotationImage:annotationImage];
                }

                annotationImagesForAnnotation[annotationValue] = annotationImage;
            }

            VMGLAnnotationTag annotationTag = self.vmglMap.addAnnotation(mbgl::SymbolAnnotation {
                VMGLPointFromLocationCoordinate2D(annotation.coordinate),
                symbolName.UTF8String
            });

            VMGLAnnotationContext context;
            context.annotation = annotation;
            VMGLAnnotationImage *annotationImage = annotationImagesForAnnotation[annotationValue];
            context.imageReuseIdentifier = annotationImage.reuseIdentifier;

            if (annotationView) {
                context.annotationView = annotationView;
                context.viewReuseIdentifier = annotationView.reuseIdentifier;
            }

            _annotationTagsByAnnotation[annotation] = annotationTag;
            _annotationContextsByAnnotationTag[annotationTag] = context;

            if ([annotation isKindOfClass:[NSObject class]]) {
                MGLAssert(![annotation isKindOfClass:[VMGLMultiPoint class]], @"Point annotation should not be MGLMultiPoint.");
                [(NSObject *)annotation addObserver:self forKeyPath:@"coordinate" options:0 context:(void *)(NSUInteger)annotationTag];
            }
        }
    }

    [self updateAnnotationContainerViewWithAnnotationViews:newAnnotationViews];

    [self didChangeValueForKey:@"annotations"];
    if (_isChangingAnnotationLayers)
    {
        [self.style willChangeValueForKey:@"layers"];
    }

    if ([self.delegate respondsToSelector:@selector(mapView:didAddAnnotationViews:)])
    {
        [self.delegate mapView:self didAddAnnotationViews:newAnnotationViews];
    }

    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

- (void)updateAnnotationContainerViewWithAnnotationViews:(NSArray<VMGLAnnotationView *> *)annotationViews
{
    if (annotationViews.count == 0) return;

    VMGLAnnotationContainerView *newAnnotationContainerView;
    if (self.annotationContainerView)
    {
        // reload any previously added views
        newAnnotationContainerView = [VMGLAnnotationContainerView annotationContainerViewWithAnnotationContainerView:self.annotationContainerView];
        [self.annotationContainerView removeFromSuperview];
    }
    else
    {
        newAnnotationContainerView = [[VMGLAnnotationContainerView alloc] initWithFrame:self.bounds];
    }
    newAnnotationContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    newAnnotationContainerView.contentMode = UIViewContentModeCenter;
    [newAnnotationContainerView addSubviews:annotationViews];
    [_mbglView->getView() insertSubview:newAnnotationContainerView atIndex:0];
    self.annotationContainerView = newAnnotationContainerView;
    
    [self updatePresentsWithTransaction];
}

/// Initialize and return a default annotation image that depicts a round pin
/// rising from the center, with a shadow slightly below center. The alignment
/// rect therefore excludes the bottom half.
- (VMGLAnnotationImage *)defaultAnnotationImage
{
    UIImage *image = [UIImage mgl_resourceImageNamed:VMGLDefaultStyleMarkerSymbolName];
    image = [image imageWithAlignmentRectInsets:
             UIEdgeInsetsMake(0, 0, image.size.height / 2, 0)];
    VMGLAnnotationImage *annotationImage = [VMGLAnnotationImage annotationImageWithImage:image
                                                                       reuseIdentifier:VMGLDefaultStyleMarkerSymbolName];
    annotationImage.styleIconIdentifier = [VMGLAnnotationSpritePrefix stringByAppendingString:annotationImage.reuseIdentifier];
    return annotationImage;
}

- (VMGLAnnotationImage *)invisibleAnnotationImage
{
    VMGLAnnotationImage *annotationImage = [self dequeueReusableAnnotationImageWithIdentifier:VMGLInvisibleStyleMarkerSymbolName];

    if (!annotationImage)
    {
        UIGraphicsBeginImageContext(CGSizeMake(1, 1));
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        annotationImage = [VMGLAnnotationImage annotationImageWithImage:image
                                                                           reuseIdentifier:VMGLInvisibleStyleMarkerSymbolName];
        annotationImage.styleIconIdentifier = [VMGLAnnotationSpritePrefix stringByAppendingString:annotationImage.reuseIdentifier];
    }

    return annotationImage;
}

- (VMGLAnnotationView *)annotationViewForAnnotation:(id<VMGLAnnotation>)annotation
{
    VMGLAnnotationView *annotationView = [self.delegate mapView:self viewForAnnotation:annotation];

    if (annotationView)
    {
        // Make sure that the annotation views are selected/deselected correctly because
        // annotations are not dismissed when they move out of the visible bounds
        BOOL isViewForSelectedAnnotation = self.selectedAnnotation == annotation;
        [annotationView setSelected:isViewForSelectedAnnotation];

        annotationView.annotation = annotation;
        annotationView.mapView = self;
        CGRect bounds = UIEdgeInsetsInsetRect({ CGPointZero, annotationView.frame.size }, annotationView.alignmentRectInsets);

        // Take any offset into consideration
        CGFloat adjustedAnnotationWidth = CGRectGetWidth(bounds) + fabs(annotationView.centerOffset.dx);
        CGFloat adjustedAnnotationHeight = CGRectGetHeight(bounds) + fabs(annotationView.centerOffset.dx);

        _largestAnnotationViewSize = CGSizeMake(MAX(_largestAnnotationViewSize.width, adjustedAnnotationWidth),
                                                MAX(_largestAnnotationViewSize.height, adjustedAnnotationHeight));

        _unionedAnnotationRepresentationSize = CGSizeMake(MAX(_unionedAnnotationRepresentationSize.width, _largestAnnotationViewSize.width),
                                                          MAX(_unionedAnnotationRepresentationSize.height, _largestAnnotationViewSize.height));
    }

    return annotationView;
}

- (nullable VMGLAnnotationView *)viewForAnnotation:(id<VMGLAnnotation>)annotation
{
    MGLLogDebug(@"Retrieving the annotation view for: %@", annotation);
    if (annotation == self.userLocation)
    {
        return self.userLocationAnnotationView;
    }
    VMGLAnnotationTag annotationTag = [self annotationTagForAnnotation:annotation];
    if (annotationTag == VMGLAnnotationTagNotFound) {
        return nil;
    }
    VMGLAnnotationContext &annotationContext = _annotationContextsByAnnotationTag.at(annotationTag);
    return annotationContext.annotationView;
}

- (double)alphaForShapeAnnotation:(VMGLShape *)annotation
{
    if (_delegateHasAlphasForShapeAnnotations)
    {
        return [self.delegate mapView:self alphaForShapeAnnotation:annotation];
    }
    return 1.0;
}

- (mbgl::Color)strokeColorForShapeAnnotation:(VMGLShape *)annotation
{
    UIColor *color = (_delegateHasStrokeColorsForShapeAnnotations
                      ? [self.delegate mapView:self strokeColorForShapeAnnotation:annotation]
                      : self.tintColor);
    return color.mgl_color;
}

- (mbgl::Color)fillColorForPolygonAnnotation:(VMGLPolygon *)annotation
{
    UIColor *color = (_delegateHasFillColorsForShapeAnnotations
                      ? [self.delegate mapView:self fillColorForPolygonAnnotation:annotation]
                      : self.tintColor);
    return color.mgl_color;
}

- (CGFloat)lineWidthForPolylineAnnotation:(VMGLPolyline *)annotation
{
    if (_delegateHasLineWidthsForShapeAnnotations)
    {
        return [self.delegate mapView:self lineWidthForPolylineAnnotation:(VMGLPolyline *)annotation];
    }
    return 3.0;
}

- (void)installAnnotationImage:(VMGLAnnotationImage *)annotationImage
{
    NSString *iconIdentifier = annotationImage.styleIconIdentifier;
    self.annotationImagesByIdentifier[annotationImage.reuseIdentifier] = annotationImage;
    annotationImage.delegate = self;

    // add sprite
    self.vmglMap.addAnnotationImage([annotationImage.image mgl_styleImageWithIdentifier:iconIdentifier]);

    // Create a slop area with a “radius” equal in size to the annotation
    // image’s alignment rect, allowing the eventual tap to be on any point
    // within this image. Union this slop area with any existing slop areas.
    CGRect bounds = UIEdgeInsetsInsetRect({ CGPointZero, annotationImage.image.size },
                                          annotationImage.image.alignmentRectInsets);
    _unionedAnnotationRepresentationSize = CGSizeMake(MAX(_unionedAnnotationRepresentationSize.width, bounds.size.width),
                                                      MAX(_unionedAnnotationRepresentationSize.height, bounds.size.height));
}

- (void)removeAnnotation:(id <VMGLAnnotation>)annotation
{
    MGLLogDebug(@"Removing annotation: %@", annotation);
    if ( ! annotation) return;

    // The core bulk deletion API is efficient with respect to indexing
    // and screen refreshes, thus we should defer to it even for
    // individual deletes.
    //
    [self removeAnnotations:@[ annotation ]];
}

- (void)removeAnnotations:(NSArray<id <VMGLAnnotation>> *)annotations
{
    MGLLogDebug(@"Removing: %lu annotations", annotations.count);
    if ( ! annotations) return;

    [self willChangeValueForKey:@"annotations"];

    for (id <VMGLAnnotation> annotation in annotations)
    {
        MGLAssert([annotation conformsToProtocol:@protocol(VMGLAnnotation)], @"annotation should conform to MGLAnnotation");

        VMGLAnnotationTag annotationTag = [self annotationTagForAnnotation:annotation];
        if (annotationTag == VMGLAnnotationTagNotFound)
        {
            continue;
        }

        VMGLAnnotationContext &annotationContext = _annotationContextsByAnnotationTag.at(annotationTag);
        VMGLAnnotationView *annotationView = annotationContext.annotationView;

        if (annotationContext.viewReuseIdentifier)
        {
            NSMutableArray *annotationViewReuseQueue = [self annotationViewReuseQueueForIdentifier:annotationContext.viewReuseIdentifier];
            if (![annotationViewReuseQueue containsObject:annotationView])
            {
                [annotationViewReuseQueue removeObject:annotationView];
            }
        }

        annotationView.annotation = nil;
        [annotationView removeFromSuperview];
        [self.annotationContainerView.annotationViews removeObject:annotationView];

        if (annotationTag == _selectedAnnotationTag)
        {
            [self deselectAnnotation:annotation animated:NO];
        }

        _annotationContextsByAnnotationTag.erase(annotationTag);
        _annotationTagsByAnnotation.erase(annotation);

        if ([annotation isKindOfClass:[NSObject class]] && ![annotation isKindOfClass:[VMGLMultiPoint class]])
        {
            [(NSObject *)annotation removeObserver:self forKeyPath:@"coordinate" context:(void *)(NSUInteger)annotationTag];
        }
        else if ([annotation isKindOfClass:[VMGLMultiPoint class]])
        {
            [(NSObject *)annotation removeObserver:self forKeyPath:@"coordinates" context:(void *)(NSUInteger)annotationTag];
        }

        _isChangingAnnotationLayers = YES;
        // If the underlying map is gone, there’s nothing to remove, but still
        // continue to unregister KVO and other annotation resources.
        if (_mbglMap)
        {
            self.vmglMap.removeAnnotation(annotationTag);
        }
    }

    [self updatePresentsWithTransaction];

    [self didChangeValueForKey:@"annotations"];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
    if (_isChangingAnnotationLayers)
    {
        [self.style willChangeValueForKey:@"layers"];
    }
}

- (nonnull NSArray<id <VMGLOverlay>> *)overlays
{
    if (self.annotations == nil) { return @[]; }

    NSMutableArray<id <VMGLOverlay>> *mutableOverlays = [NSMutableArray array];

    [self.annotations enumerateObjectsUsingBlock:^(id<VMGLAnnotation>  _Nonnull annotation, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([annotation conformsToProtocol:@protocol(VMGLOverlay)])
        {
            [mutableOverlays addObject:(id<VMGLOverlay>)annotation];
        }
    }];

    return [NSArray arrayWithArray:mutableOverlays];
}

- (void)addOverlay:(id <VMGLOverlay>)overlay
{
    MGLLogDebug(@"Adding overlay: %@", overlay);
    [self addOverlays:@[ overlay ]];
}

- (void)addOverlays:(NSArray<id <VMGLOverlay>> *)overlays
{
    MGLLogDebug(@"Adding: %lu overlays", overlays.count);
#if DEBUG
    for (id <VMGLOverlay> overlay in overlays)
    {
        MGLAssert([overlay conformsToProtocol:@protocol(VMGLOverlay)], @"overlay should conform to MGLOverlay");
    }
#endif

    [self addAnnotations:overlays];
}

- (void)removeOverlay:(id <VMGLOverlay>)overlay
{
    MGLLogDebug(@"Removing overlay: %@", overlay);
    [self removeOverlays:@[ overlay ]];
}

- (void)removeOverlays:(NSArray<id <VMGLOverlay>> *)overlays
{
    MGLLogDebug(@"Removing: %lu overlays", overlays.count);
#if DEBUG
    for (id <VMGLOverlay> overlay in overlays)
    {
        MGLAssert([overlay conformsToProtocol:@protocol(VMGLOverlay)], @"overlay should conform to MGLOverlay");
    }
#endif

    [self removeAnnotations:overlays];
}

- (nullable VMGLAnnotationImage *)dequeueReusableAnnotationImageWithIdentifier:(NSString *)identifier
{
    return self.annotationImagesByIdentifier[identifier];
}

- (nullable VMGLAnnotationView *)dequeueReusableAnnotationViewWithIdentifier:(NSString *)identifier
{
    NSMutableArray *annotationViewReuseQueue = [self annotationViewReuseQueueForIdentifier:identifier];
    VMGLAnnotationView *reusableView = annotationViewReuseQueue.firstObject;
    [reusableView prepareForReuse];
    [annotationViewReuseQueue removeObject:reusableView];

    return reusableView;
}

/**
    Returns the tag of the annotation at the given point in the view.

    This is more involved than it sounds: if multiple point annotations overlap
    near the point, this method cycles through them so that each of them is
    accessible to the user at some point.

    @param persist True to remember the cycleable set of annotations, so that a
        different annotation is returned the next time this method is called
        with the same point. Setting this parameter to false is useful for
        asking “what if?”
 */
- (VMGLAnnotationTag)annotationTagAtPoint:(CGPoint)point persistingResults:(BOOL)persist
{
    // Look for any annotation near the tap. An annotation is “near” if the
    // distance between its center and the tap is less than the maximum height
    // or width of an installed annotation image or annotation view.
    CGRect queryRect = CGRectInset({ point, CGSizeZero },
                                   -_unionedAnnotationRepresentationSize.width,
                                   -_unionedAnnotationRepresentationSize.height);
    queryRect = CGRectInset(queryRect, -VMGLAnnotationImagePaddingForHitTest,
                            -VMGLAnnotationImagePaddingForHitTest);
    std::vector<VMGLAnnotationTag> nearbyAnnotations = [self annotationTagsInRect:queryRect];
    std::vector<VMGLAnnotationTag> nearbyShapeAnnotations = [self shapeAnnotationTagsInRect:queryRect];
    
    if (nearbyShapeAnnotations.size()) {
        nearbyAnnotations.insert(nearbyAnnotations.end(), nearbyShapeAnnotations.begin(), nearbyShapeAnnotations.end());
    }

    if (nearbyAnnotations.size())
    {
        // Assume that the user is fat-fingering an annotation.
        CGRect hitRect = CGRectInset({ point, CGSizeZero },
                                     -VMGLAnnotationImagePaddingForHitTest,
                                     -VMGLAnnotationImagePaddingForHitTest);
        
        // Filter out any annotation whose image or view is unselectable or for which
        // hit testing fails.
        auto end = std::remove_if(nearbyAnnotations.begin(), nearbyAnnotations.end(), [&](const VMGLAnnotationTag annotationTag) {
            id <VMGLAnnotation> annotation = [self annotationWithTag:annotationTag];
            MGLAssert(annotation, @"Unknown annotation found nearby tap");
            if ( ! annotation)
            {
                return true;
            }
            
            VMGLAnnotationContext annotationContext = _annotationContextsByAnnotationTag.at(annotationTag);
            CGRect annotationRect;
            
            VMGLAnnotationView *annotationView = annotationContext.annotationView;
            
            if (annotationView)
            {
                if ( ! annotationView.enabled)
                {
                    return true;
                }

                CGPoint calloutAnchorPoint = VMGLPointRounded([self convertCoordinate:annotation.coordinate toPointToView:self]);
                CGRect frame = CGRectInset({ calloutAnchorPoint, CGSizeZero }, -CGRectGetWidth(annotationView.frame) / 2, -CGRectGetHeight(annotationView.frame) / 2);

                // We need to take any offset into consideration. Note that a large offset will result in a
                // large value for `_unionedAnnotationRepresentationSize` (and thus a larger feature query rect).
                // Aim to keep the offset as small as possible.
                frame = CGRectOffset(frame, annotationView.centerOffset.dx, annotationView.centerOffset.dy);

                annotationRect = UIEdgeInsetsInsetRect(frame, annotationView.alignmentRectInsets);
            }
            else
            {
                if ([annotation isKindOfClass:[VMGLMultiPoint class]])
                {
                    if ([self.delegate respondsToSelector:@selector(mapView:shapeAnnotationIsEnabled:)]) {
                        return !!(![self.delegate mapView:self shapeAnnotationIsEnabled:(VMGLMultiPoint *)annotation]);
                    } else {
                        return false;
                    }
                }
                
                VMGLAnnotationImage *annotationImage = [self imageOfAnnotationWithTag:annotationTag];
                if ( ! annotationImage.enabled)
                {
                    return true;
                }
                
                VMGLAnnotationImage *fallbackAnnotationImage = [self dequeueReusableAnnotationImageWithIdentifier:VMGLDefaultStyleMarkerSymbolName];
                UIImage *fallbackImage = fallbackAnnotationImage.image;
                
                annotationRect = [self frameOfImage:annotationImage.image ?: fallbackImage centeredAtCoordinate:annotation.coordinate];
            }
            
            // Filter out the annotation if the fattened finger didn’t land
            // within the image’s alignment rect.
            return !!!CGRectIntersectsRect(annotationRect, hitRect);
        });
        
        nearbyAnnotations.resize(std::distance(nearbyAnnotations.begin(), end));

    }

    VMGLAnnotationTag hitAnnotationTag = VMGLAnnotationTagNotFound;
    if (nearbyAnnotations.size())
    {
        // The first selection in the cycle should be the one nearest to the
        // tap. Also the annotation tags need to be stable in order to compare them with
        // the remembered tags _annotationsNearbyLastTap.
        CLLocationCoordinate2D currentCoordinate = [self convertPoint:point toCoordinateFromView:self];
        std::sort(nearbyAnnotations.begin(), nearbyAnnotations.end(), [&](const VMGLAnnotationTag tagA, const VMGLAnnotationTag tagB) {
            CLLocationCoordinate2D coordinateA = [[self annotationWithTag:tagA] coordinate];
            CLLocationCoordinate2D coordinateB = [[self annotationWithTag:tagB] coordinate];
            CLLocationDegrees deltaA = hypot(coordinateA.latitude - currentCoordinate.latitude,
                                             coordinateA.longitude - currentCoordinate.longitude);
            CLLocationDegrees deltaB = hypot(coordinateB.latitude - currentCoordinate.latitude,
                                             coordinateB.longitude - currentCoordinate.longitude);
            return deltaA < deltaB;
        });
        
        if (nearbyAnnotations == _annotationsNearbyLastTap)
        {
            // The last time we persisted a set of annotations, we had the same
            // set of annotations as we do now. Cycle through them.
            if (_selectedAnnotationTag == VMGLAnnotationTagNotFound
                || _selectedAnnotationTag == nearbyAnnotations.back())
            {
                // Either no annotation is selected or the last annotation in
                // the set was selected. Wrap around to the first annotation in
                // the set.
                hitAnnotationTag = nearbyAnnotations.front();
            }
            else
            {
                auto result = std::find(nearbyAnnotations.begin(),
                                        nearbyAnnotations.end(),
                                        _selectedAnnotationTag);
                if (result == nearbyAnnotations.end())
                {
                    // An annotation from this set hasn’t been selected before.
                    // Select the first (nearest) one.
                    hitAnnotationTag = nearbyAnnotations.front();
                }
                else
                {
                    // Step to the next annotation in the set.
                    auto distance = std::distance(nearbyAnnotations.begin(), result);
                    hitAnnotationTag = nearbyAnnotations[distance + 1];
                }
            }
        }
        else
        {
            // Remember the nearby annotations for the next time this method is
            // called.
            if (persist)
            {
                _annotationsNearbyLastTap = nearbyAnnotations;
            }
            
            // Choose the first nearby annotation.
            if (nearbyAnnotations.size())
            {
                hitAnnotationTag = nearbyAnnotations.front();
            }
        }
    }

    return hitAnnotationTag;
}

/// Returns the tags of the annotations coincident with the given rectangle.
- (std::vector<VMGLAnnotationTag>)annotationTagsInRect:(CGRect)rect
{
    return _rendererFrontend->getRenderer()->queryPointAnnotations({
        { CGRectGetMinX(rect), CGRectGetMinY(rect) },
        { CGRectGetMaxX(rect), CGRectGetMaxY(rect) },
    });
}

- (std::vector<VMGLAnnotationTag>)shapeAnnotationTagsInRect:(CGRect)rect
{
    return _rendererFrontend->getRenderer()->queryShapeAnnotations({
        { CGRectGetMinX(rect), CGRectGetMinY(rect) },
        { CGRectGetMaxX(rect), CGRectGetMaxY(rect) },
    });
}


- (BOOL)isMovingAnnotationIntoViewSupportedForAnnotation:(id<VMGLAnnotation>)annotation animated:(BOOL)animated {
    // Consider delegating
    return [annotation isKindOfClass:[VMPointAnnotation class]];
}

- (id <VMGLAnnotation>)selectedAnnotation
{
    if (_userLocationAnnotationIsSelected)
    {
        return self.userLocation;
    }

    if ( ! _annotationContextsByAnnotationTag.count(_selectedAnnotationTag) ||
        _selectedAnnotationTag == VMGLAnnotationTagNotFound) {
        return nil;
    }

    VMGLAnnotationContext &annotationContext = _annotationContextsByAnnotationTag.at(_selectedAnnotationTag);
    return annotationContext.annotation;
}

- (void)setSelectedAnnotation:(id <VMGLAnnotation>)annotation
{
    MGLLogDebug(@"Selecting annotation: %@", annotation);
    [self willChangeValueForKey:@"selectedAnnotations"];
    _selectedAnnotationTag = [self annotationTagForAnnotation:annotation];
    _userLocationAnnotationIsSelected = annotation && annotation == self.userLocation;
    [self didChangeValueForKey:@"selectedAnnotations"];
}

- (NSArray<id <VMGLAnnotation>> *)selectedAnnotations
{
    id <VMGLAnnotation> selectedAnnotation = self.selectedAnnotation;
    return (selectedAnnotation ? @[ selectedAnnotation ] : @[]);
}

- (void)setSelectedAnnotations:(NSArray<id <VMGLAnnotation>> *)selectedAnnotations
{
    if ( ! selectedAnnotations.count) return;

    id <VMGLAnnotation> firstAnnotation = selectedAnnotations[0];

    MGLAssert([firstAnnotation conformsToProtocol:@protocol(VMGLAnnotation)], @"annotation should conform to MGLAnnotation");

    if ([firstAnnotation isKindOfClass:[VMGLMultiPoint class]]) return;

    [self selectAnnotation:firstAnnotation animated:YES completionHandler:nil];
}

- (void)selectAnnotation:(id <VMGLAnnotation>)annotation animated:(BOOL)animated
{
    [self selectAnnotation:annotation animated:animated completionHandler:nil];
}

- (void)selectAnnotation:(id <VMGLAnnotation>)annotation animated:(BOOL)animated completionHandler:(nullable void (^)(void))completion
{
    [self selectAnnotation:annotation moveIntoView:animated animateSelection:animated completionHandler:completion];
}

- (void)selectAnnotation:(id <VMGLAnnotation>)annotation moveIntoView:(BOOL)moveIntoView animateSelection:(BOOL)animateSelection completionHandler:(nullable void (^)(void))completion
{
    MGLLogDebug(@"Selecting annotation: %@ moveIntoView: %@ animateSelection: %@", annotation, VMGLStringFromBOOL(moveIntoView), VMGLStringFromBOOL(animateSelection));
    CGRect positioningRect = [self positioningRectForAnnotation:annotation defaultCalloutPoint:CGPointZero];
    [self selectAnnotation:annotation moveIntoView:moveIntoView animateSelection:animateSelection calloutPositioningRect:positioningRect completionHandler:completion];
}

- (void)selectAnnotation:(id <VMGLAnnotation>)annotation moveIntoView:(BOOL)moveIntoView animateSelection:(BOOL)animateSelection calloutPositioningRect:(CGRect)calloutPositioningRect completionHandler:(nullable void (^)(void))completion
{
    if ( ! annotation) return;

    if (annotation == self.selectedAnnotation) return;

    [self deselectAnnotation:self.selectedAnnotation animated:NO];

    // Add the annotation to the map if it hasn’t been added yet.
    VMGLAnnotationTag annotationTag = [self annotationTagForAnnotation:annotation];
    if (annotationTag == VMGLAnnotationTagNotFound && annotation != self.userLocation)
    {
        [self addAnnotation:annotation];
        annotationTag = [self annotationTagForAnnotation:annotation];
        if (annotationTag == VMGLAnnotationTagNotFound) return;
    }

    VMGLAnnotationView *annotationView = nil;

    if (annotation != self.userLocation)
        if (annotationTag != VMGLAnnotationTagNotFound) {
            VMGLAnnotationContext &annotationContext = _annotationContextsByAnnotationTag.at(annotationTag);
            annotationView = annotationContext.annotationView;
            if (annotationView && annotationView.enabled) {
                // Annotations represented by views use the view frame as the positioning rect.
                calloutPositioningRect = annotationView.frame;
                [annotationView.superview bringSubviewToFront:annotationView];

                [annotationView setSelected:YES animated:animateSelection];
            }
        }

    self.selectedAnnotation = annotation;

    // Determine if we're allowed to move this offscreen annotation on screen, even though we've asked it to
    if (moveIntoView) {
        moveIntoView = [self isMovingAnnotationIntoViewSupportedForAnnotation:annotation animated:animateSelection];
    }

    // If we have an invalid positioning rect, we need to provide a suitable default.
    // This (currently) happens if you select an annotation that has NOT yet been
    // added. See https://github.com/mapbox/mapbox-gl-native/issues/11476
    if (CGRectIsNull(calloutPositioningRect)) {
        CLLocationCoordinate2D origin = annotation.coordinate;
        CGPoint originPoint = [self convertCoordinate:origin toPointToView:self];
        calloutPositioningRect = { .origin = originPoint, .size = CGSizeZero };
    }
    
    CGRect expandedPositioningRect = calloutPositioningRect;

    // Used for callout positioning, and moving offscreen annotations onscreen.
    CGRect constrainedRect = self.contentFrame;
    CGRect bounds = constrainedRect;

    BOOL expandedPositioningRectToMoveCalloutIntoViewWithMargins = NO;
    
    UIView <VMGLCalloutView> *calloutView = nil;

    if ([annotation respondsToSelector:@selector(title)] &&
        annotation.title &&
        [self.delegate respondsToSelector:@selector(mapView:annotationCanShowCallout:)] &&
        [self.delegate mapView:self annotationCanShowCallout:annotation])
    {
        // build the callout
        if ([self.delegate respondsToSelector:@selector(mapView:calloutViewForAnnotation:)])
        {
            id providedCalloutView = [self.delegate mapView:self calloutViewForAnnotation:annotation];
            if (providedCalloutView) {
                if (![providedCalloutView isKindOfClass:[UIView class]]) {
                    [NSException raise:NSInvalidArgumentException format:@"Callout view must be a kind of UIView"];
                }
                MGLAssert([providedCalloutView conformsToProtocol:@protocol(VMGLCalloutView)], @"callout view must conform to MGLCalloutView");
                calloutView = providedCalloutView;
            }
        }
        if (!calloutView)
        {
            calloutView = [self calloutViewForAnnotation:annotation];
        }
        self.calloutViewForSelectedAnnotation = calloutView;

        if (_userLocationAnnotationIsSelected)
        {
            calloutPositioningRect = [self.userLocationAnnotationView.layer.presentationLayer frame];

            CGRect implicitAnnotationFrame = [self.userLocationAnnotationView.layer.presentationLayer frame];
            CGRect explicitAnnotationFrame = self.userLocationAnnotationView.frame;
            _initialImplicitCalloutViewOffset = CGPointMake(CGRectGetMinX(explicitAnnotationFrame) - CGRectGetMinX(implicitAnnotationFrame),
                                                            CGRectGetMinY(explicitAnnotationFrame) - CGRectGetMinY(implicitAnnotationFrame));
        }

        // consult delegate for left and/or right accessory views
        if ([self.delegate respondsToSelector:@selector(mapView:leftCalloutAccessoryViewForAnnotation:)])
        {
            calloutView.leftAccessoryView = [self.delegate mapView:self leftCalloutAccessoryViewForAnnotation:annotation];

            if ([calloutView.leftAccessoryView isKindOfClass:[UIControl class]])
            {
                UITapGestureRecognizer *calloutAccessoryTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                                      action:@selector(handleCalloutAccessoryTapGesture:)];

                [calloutView.leftAccessoryView addGestureRecognizer:calloutAccessoryTap];
            }
        }

        if ([self.delegate respondsToSelector:@selector(mapView:rightCalloutAccessoryViewForAnnotation:)])
        {
            calloutView.rightAccessoryView = [self.delegate mapView:self rightCalloutAccessoryViewForAnnotation:annotation];

            if ([calloutView.rightAccessoryView isKindOfClass:[UIControl class]])
            {
                UITapGestureRecognizer *calloutAccessoryTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                                      action:@selector(handleCalloutAccessoryTapGesture:)];

                [calloutView.rightAccessoryView addGestureRecognizer:calloutAccessoryTap];
            }
        }

        // set annotation delegate to handle taps on the callout view
        calloutView.delegate = self;

        // If the callout view provides inset (outset) information, we can use it to expand our positioning
        // rect, which we then use to help move the annotation on-screen if want need to.
        if (moveIntoView && [calloutView respondsToSelector:@selector(marginInsetsHintForPresentationFromRect:)]) {
            UIEdgeInsets margins = [calloutView marginInsetsHintForPresentationFromRect:calloutPositioningRect];
            expandedPositioningRect = UIEdgeInsetsInsetRect(expandedPositioningRect, margins);
            expandedPositioningRectToMoveCalloutIntoViewWithMargins = YES;
        }
    }
    
    if (!expandedPositioningRectToMoveCalloutIntoViewWithMargins)
    {
        // We don't have a callout (OR our callout didn't implement
        // marginInsetsHintForPresentationFromRect: - in this case we need to
        // ensure that partially off-screen annotations are NOT moved into view.
        //
        // We may want to create (and fallback to) an `MGLMapViewDelegate` version
        // of the `-[MGLCalloutView marginInsetsHintForPresentationFromRect:]
        // protocol method.
        bounds = CGRectInset(bounds, -calloutPositioningRect.size.width, -calloutPositioningRect.size.height);
    }

    if (moveIntoView)
    {
        moveIntoView = NO;

        // Any one of these cases should trigger a move onscreen
        CGFloat minX = CGRectGetMinX(expandedPositioningRect);
        
        if (minX < CGRectGetMinX(bounds)) {
            constrainedRect.origin.x = minX;
            moveIntoView = YES;
        }
        else {
            CGFloat maxX = CGRectGetMaxX(expandedPositioningRect);
            
            if (maxX > CGRectGetMaxX(bounds)) {
                constrainedRect.origin.x = maxX - CGRectGetWidth(constrainedRect);
                moveIntoView = YES;
            }
        }

        CGFloat minY = CGRectGetMinY(expandedPositioningRect);
        
        if (minY < CGRectGetMinY(bounds)) {
            constrainedRect.origin.y = minY;
            moveIntoView = YES;
        }
        else {
            CGFloat maxY = CGRectGetMaxY(expandedPositioningRect);
            
            if (maxY > CGRectGetMaxY(bounds)) {
                constrainedRect.origin.y = maxY - CGRectGetHeight(constrainedRect);
                moveIntoView = YES;
            }
        }
    }

    // Remember, calloutView can be nil here.
    [calloutView presentCalloutFromRect:calloutPositioningRect
                                 inView:_mbglView->getView()
                      constrainedToRect:constrainedRect
                               animated:animateSelection];

    // Save the anchor coordinate
    if ([annotation isKindOfClass:[VMPointAnnotation class]]) {
        self.anchorCoordinateForSelectedAnnotation = annotation.coordinate;
    }
    else {
        // This is used for features like polygons, so that if the map is dragged
        // the callout doesn't ping to its coordinate.
        CGPoint anchorPoint = CGPointMake(CGRectGetMidX(calloutPositioningRect), CGRectGetMidY(calloutPositioningRect));
        self.anchorCoordinateForSelectedAnnotation = [self convertPoint:anchorPoint toCoordinateFromView:self];
    }
        
    // notify delegate
    if ([self.delegate respondsToSelector:@selector(mapView:didSelectAnnotation:)])
    {
        [self.delegate mapView:self didSelectAnnotation:annotation];
    }

    if (annotationView && [self.delegate respondsToSelector:@selector(mapView:didSelectAnnotationView:)])
    {
        [self.delegate mapView:self didSelectAnnotationView:annotationView];
    }

    if (moveIntoView)
    {
        CGPoint center = CGPointMake(CGRectGetMidX(constrainedRect), CGRectGetMidY(constrainedRect));
        CLLocationCoordinate2D centerCoord = [self convertPoint:center toCoordinateFromView:self];
        [self setCenterCoordinate:centerCoord zoomLevel:self.zoomLevel direction:self.direction animated:animateSelection completionHandler:completion];
    }
    else if (completion)
    {
        completion();
    }
}

- (VMGLCompactCalloutView *)calloutViewForAnnotation:(id <VMGLAnnotation>)annotation
{
    VMGLCompactCalloutView *calloutView = [VMGLCompactCalloutView platformCalloutView];
    calloutView.representedObject = annotation;
    calloutView.tintColor = self.tintColor;

    return calloutView;
}

/// Returns the rectangle that represents the annotation image of the annotation
/// with the given tag. This rectangle is fitted to the image’s alignment rect
/// and is appropriate for positioning a popover.
/// If a shape annotation is visible but its centroid is not, and a default point is specified,
/// the callout view is anchored to the default callout point.
- (CGRect)positioningRectForAnnotation:(id <VMGLAnnotation>)annotation defaultCalloutPoint:(CGPoint)calloutPoint
{
    VMGLAnnotationTag annotationTag = [self annotationTagForAnnotation:annotation];
    CGRect positioningRect = [self positioningRectForCalloutForAnnotationWithTag:annotationTag];

    if (CGRectIsNull(positioningRect)) {
        return positioningRect;
    }

    // For annotations which `coordinate` falls offscreen it will use the current tap point as anchor instead.
    if ( ! CGRectIntersectsRect(positioningRect, self.bounds) && annotation != self.userLocation)
    {
        if (!CGPointEqualToPoint(calloutPoint, CGPointZero)) {
            positioningRect = CGRectMake(calloutPoint.x, calloutPoint.y, positioningRect.size.width, positioningRect.size.height);
        }
    }
    
    return positioningRect;
}

/// Returns the rectangle that represents the annotation image of the annotation
/// with the given tag. This rectangle is fitted to the image’s alignment rect
/// and is appropriate for positioning a popover.
- (CGRect)positioningRectForCalloutForAnnotationWithTag:(VMGLAnnotationTag)annotationTag
{
    id <VMGLAnnotation> annotation = [self annotationWithTag:annotationTag];
    if ( ! annotation)
    {
        return CGRectNull;
    }
    
    CLLocationCoordinate2D coordinate;
    
    if ((annotation == self.selectedAnnotation) &&
        CLLocationCoordinate2DIsValid(self.anchorCoordinateForSelectedAnnotation)) {
        coordinate = self.anchorCoordinateForSelectedAnnotation;
    }
    else {
        coordinate = annotation.coordinate;
    }
    
    if ([annotation isKindOfClass:[VMGLMultiPoint class]]) {
        CLLocationCoordinate2D origin = coordinate;
        CGPoint originPoint = [self convertCoordinate:origin toPointToView:self];
        return CGRectMake(originPoint.x, originPoint.y, VMGLAnnotationImagePaddingForHitTest, VMGLAnnotationImagePaddingForHitTest);
    }
    
    UIImage *image = [self imageOfAnnotationWithTag:annotationTag].image;
    if ( ! image)
    {
        image = [self dequeueReusableAnnotationImageWithIdentifier:VMGLDefaultStyleMarkerSymbolName].image;
    }
    if ( ! image)
    {
        return CGRectZero;
    }

    CGRect positioningRect = [self frameOfImage:image centeredAtCoordinate:coordinate];
    positioningRect.origin.x -= 0.5;

    return CGRectInset(positioningRect, -VMGLAnnotationImagePaddingForCallout,
                       -VMGLAnnotationImagePaddingForCallout);
}

/// Returns the rectangle relative to the viewport that represents the given
/// image centered at the given coordinate.
- (CGRect)frameOfImage:(UIImage *)image centeredAtCoordinate:(CLLocationCoordinate2D)coordinate
{
    CGPoint calloutAnchorPoint = VMGLPointRounded([self convertCoordinate:coordinate toPointToView:self]);
    CGRect frame = CGRectInset({ calloutAnchorPoint, CGSizeZero }, -image.size.width / 2, -image.size.height / 2);
    return UIEdgeInsetsInsetRect(frame, image.alignmentRectInsets);
}

/// Returns the annotation image assigned to the annotation with the given tag.
- (VMGLAnnotationImage *)imageOfAnnotationWithTag:(VMGLAnnotationTag)annotationTag
{
    if (annotationTag == VMGLAnnotationTagNotFound
        || _annotationContextsByAnnotationTag.count(annotationTag) == 0)
    {
        return nil;
    }

    NSString *customSymbol = _annotationContextsByAnnotationTag.at(annotationTag).imageReuseIdentifier;
    NSString *symbolName = customSymbol.length ? customSymbol : VMGLDefaultStyleMarkerSymbolName;

    return [self dequeueReusableAnnotationImageWithIdentifier:symbolName];
}

- (void)deselectAnnotation:(id <VMGLAnnotation>)annotation animated:(BOOL)animated
{
    if ( ! annotation) return;

    if (self.selectedAnnotation == annotation)
    {
        MGLLogDebug(@"Deselecting annotation: %@ animated: %@", annotation, VMGLStringFromBOOL(animated));
        // dismiss popup
        [self.calloutViewForSelectedAnnotation dismissCalloutAnimated:animated];

        // deselect annotation view
        VMGLAnnotationView *annotationView = nil;
        VMGLAnnotationTag annotationTag = [self annotationTagForAnnotation:annotation];

        if (annotationTag != VMGLAnnotationTagNotFound)
        {
            VMGLAnnotationContext &annotationContext = _annotationContextsByAnnotationTag.at(annotationTag);
            annotationView = annotationContext.annotationView;
            [annotationView setSelected:NO animated:animated];
        }

        // clean up
        self.calloutViewForSelectedAnnotation = nil;
        self.selectedAnnotation = nil;
        self.anchorCoordinateForSelectedAnnotation = kCLLocationCoordinate2DInvalid;

        // notify delegate
        if ([self.delegate respondsToSelector:@selector(mapView:didDeselectAnnotation:)])
        {
            [self.delegate mapView:self didDeselectAnnotation:annotation];
        }

        if (annotationView && [self.delegate respondsToSelector:@selector(mapView:didDeselectAnnotationView:)])
        {
            [self.delegate mapView:self didDeselectAnnotationView:annotationView];
        }
        
        [self updatePresentsWithTransaction];
    }
}

- (void)calloutViewWillAppear:(UIView <VMGLCalloutView> *)calloutView
{
    if (_userLocationAnnotationIsSelected ||
        CGPointEqualToPoint(_initialImplicitCalloutViewOffset, CGPointZero))
    {
        return;
    }

    __weak __typeof__(self) weakSelf = self;

    // The user location callout view initially points to the user location
    // annotation’s implicit (visual) frame, which is offset from the
    // annotation’s explicit frame. Now the callout view needs to rendezvous
    // with the explicit frame. Then,
    // -updateUserLocationAnnotationViewAnimatedWithDuration: will take over the
    // next time an updated location arrives.
    [UIView animateWithDuration:_userLocationAnimationCompletionDate.timeIntervalSinceNow
                          delay:0
                        options:(UIViewAnimationOptionCurveLinear |
                                 UIViewAnimationOptionAllowUserInteraction |
                                 UIViewAnimationOptionBeginFromCurrentState)
                     animations:^
     {
         __typeof__(self) strongSelf = weakSelf;
         if ( ! strongSelf)
         {
             return;
         }

         calloutView.frame = CGRectOffset(calloutView.frame,
                                          strongSelf->_initialImplicitCalloutViewOffset.x,
                                          strongSelf->_initialImplicitCalloutViewOffset.y);
         strongSelf->_initialImplicitCalloutViewOffset = CGPointZero;
     }
                     completion:NULL];
}

- (void)showAnnotations:(NSArray<id <VMGLAnnotation>> *)annotations animated:(BOOL)animated
{
    CGFloat maximumPadding = 100;
    CGFloat yPadding = (self.frame.size.height / 5 <= maximumPadding) ? (self.frame.size.height / 5) : maximumPadding;
    CGFloat xPadding = (self.frame.size.width / 5 <= maximumPadding) ? (self.frame.size.width / 5) : maximumPadding;

    UIEdgeInsets edgeInsets = UIEdgeInsetsMake(yPadding, xPadding, yPadding, xPadding);

    [self showAnnotations:annotations edgePadding:edgeInsets animated:animated completionHandler:nil];
}

- (void)showAnnotations:(NSArray<id <VMGLAnnotation>> *)annotations edgePadding:(UIEdgeInsets)insets animated:(BOOL)animated
{
    [self showAnnotations:annotations edgePadding:insets animated:animated completionHandler:nil];
}

- (void)showAnnotations:(NSArray<id <VMGLAnnotation>> *)annotations edgePadding:(UIEdgeInsets)insets animated:(BOOL)animated completionHandler:(nullable void (^)(void))completion
{
    MGLLogDebug(@"Showing: %lu annotations edgePadding: %@ animated: %@", annotations.count, NSStringFromUIEdgeInsets(insets), VMGLStringFromBOOL(animated));
    if ( ! annotations.count)
    {
        if (completion) {
            completion();
        }
        return;
    }

    mbgl::LatLngBounds bounds = mbgl::LatLngBounds::empty();

    for (id <VMGLAnnotation> annotation in annotations)
    {
        if ([annotation conformsToProtocol:@protocol(VMGLOverlay)])
        {
            bounds.extend(VMGLLatLngBoundsFromCoordinateBounds(((id <VMGLOverlay>)annotation).overlayBounds));
        }
        else
        {
            bounds.extend(VMGLLatLngFromLocationCoordinate2D(annotation.coordinate));
        }
    }

    [self setVisibleCoordinateBounds:VMGLCoordinateBoundsFromLatLngBounds(bounds)
                         edgePadding:insets
                            animated:animated
                   completionHandler:completion];
}


#pragma mark Annotation Image Delegate

- (void)annotationImageNeedsRedisplay:(VMGLAnnotationImage *)annotationImage
{
    NSString *reuseIdentifier = annotationImage.reuseIdentifier;
    NSString *iconIdentifier = annotationImage.styleIconIdentifier;
    NSString *fallbackReuseIdentifier = VMGLDefaultStyleMarkerSymbolName;
    NSString *fallbackIconIdentifier = [VMGLAnnotationSpritePrefix stringByAppendingString:fallbackReuseIdentifier];

    if (annotationImage.image)
    {
        // Add the new icon to the style.
        NSString *updatedIconIdentifier = [VMGLAnnotationSpritePrefix stringByAppendingString:annotationImage.reuseIdentifier];
        annotationImage.styleIconIdentifier = updatedIconIdentifier;
        [self installAnnotationImage:annotationImage];

        if ([iconIdentifier isEqualToString:fallbackIconIdentifier])
        {
            // Update any annotations associated with the annotation image.
            [self applyIconIdentifier:updatedIconIdentifier toAnnotationsWithImageReuseIdentifier:reuseIdentifier];
        }
    }
    else
    {
        // Add the default icon to the style if necessary.
        annotationImage.styleIconIdentifier = fallbackIconIdentifier;
        if ( ! [self dequeueReusableAnnotationImageWithIdentifier:VMGLDefaultStyleMarkerSymbolName])
        {
            [self installAnnotationImage:self.defaultAnnotationImage];
        }

        // Update any annotations associated with the annotation image.
        [self applyIconIdentifier:fallbackIconIdentifier toAnnotationsWithImageReuseIdentifier:reuseIdentifier];
    }
}

- (void)applyIconIdentifier:(NSString *)iconIdentifier toAnnotationsWithImageReuseIdentifier:(NSString *)reuseIdentifier
{
    for (auto &pair : _annotationContextsByAnnotationTag)
    {
        if ([pair.second.imageReuseIdentifier isEqualToString:reuseIdentifier])
        {
            const mbgl::Point<double> point = VMGLPointFromLocationCoordinate2D(pair.second.annotation.coordinate);
            self.vmglMap.updateAnnotation(pair.first, mbgl::SymbolAnnotation { point, iconIdentifier.UTF8String ?: "" });
        }
    }
}

#pragma mark - User Location -

- (void)setLocationManager:(nullable id<VMGLLocationManager>)locationManager
{
    MGLLogDebug(@"Setting locationManager: %@", locationManager);
    if (!locationManager) {
        locationManager = [[VMGLCLLocationManager alloc] init];
    }
    [_locationManager stopUpdatingLocation];
    [_locationManager stopUpdatingHeading];
    _locationManager.delegate = nil;
    
    _locationManager = locationManager;
    _locationManager.delegate = self;
}

- (void)validateLocationServices
{
    BOOL shouldEnableLocationServices = self.showsUserLocation && !self.dormant;

    if (shouldEnableLocationServices)
    {
        if (self.locationManager.authorizationStatus == kCLAuthorizationStatusNotDetermined) {
            BOOL hasWhenInUseUsageDescription = !![[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"];

            if (@available(iOS 11.0, *)) {
                // A WhenInUse string is required in iOS 11+ and the map never has any need for Always, so it's enough to just ask for WhenInUse.
                if (hasWhenInUseUsageDescription) {
                    [self.locationManager requestWhenInUseAuthorization];
                } else {
                    [NSException raise:VMGLMissingLocationServicesUsageDescriptionException
                                format:@"To use location services this app must have a NSLocationWhenInUseUsageDescription string in its Info.plist."];
                }
            } else {
                // We might have to ask for Always if the app does not provide a WhenInUse string.
                BOOL hasAlwaysUsageDescription = !![[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysUsageDescription"];

                if (hasWhenInUseUsageDescription) {
                    [self.locationManager requestWhenInUseAuthorization];
                } else if (hasAlwaysUsageDescription) {
                    [self.locationManager requestAlwaysAuthorization];
                } else {
                    [NSException raise:VMGLMissingLocationServicesUsageDescriptionException
                                format:@"To use location services this app must have a NSLocationWhenInUseUsageDescription and/or NSLocationAlwaysUsageDescription string in its Info.plist."];
                }
            }
        }

        [self.locationManager startUpdatingLocation];

        [self validateUserHeadingUpdating];
    }
    else if ( ! shouldEnableLocationServices && self.locationManager)
    {
        [self.locationManager stopUpdatingLocation];
        [self.locationManager stopUpdatingHeading];
    }
}

- (NSString *)accuracyDescriptionString {
    NSDictionary *dictionary = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationTemporaryUsageDescriptionDictionary"];
    return dictionary[@"MGLAccuracyAuthorizationDescription"];
}

- (void)setShowsUserLocation:(BOOL)showsUserLocation
{
    MGLLogDebug(@"Setting showsUserLocation: %@", VMGLStringFromBOOL(showsUserLocation));
    if (showsUserLocation == _showsUserLocation) return;

    _showsUserLocation = showsUserLocation;

    if (showsUserLocation)
    {
        if ([self.delegate respondsToSelector:@selector(mapViewWillStartLocatingUser:)])
        {
            [self.delegate mapViewWillStartLocatingUser:self];
        }

        self.userLocation = [[VMGLUserLocation alloc] initWithMapView:self];

        VMGLUserLocationAnnotationView *userLocationAnnotationView;

        if ([self.delegate respondsToSelector:@selector(mapView:viewForAnnotation:)])
        {
            userLocationAnnotationView = (VMGLUserLocationAnnotationView *)[self.delegate mapView:self viewForAnnotation:self.userLocation];
            if (userLocationAnnotationView && ! [userLocationAnnotationView isKindOfClass:VMGLUserLocationAnnotationView.class])
            {
                [NSException raise:VMGLUserLocationAnnotationTypeException
                            format:@"User location annotation view must be a kind of MGLUserLocationAnnotationView. %@", userLocationAnnotationView.debugDescription];
            }
        }

        self.userLocationAnnotationView = userLocationAnnotationView ?: [[VMGLFaux3DUserLocationAnnotationView alloc] init];
        self.userLocationAnnotationView.mapView = self;
        self.userLocationAnnotationView.userLocation = self.userLocation;

        self.userLocationAnnotationView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                                            UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);

        [self validateLocationServices];
    }
    else
    {
        [self validateLocationServices];

        if ([self.delegate respondsToSelector:@selector(mapViewDidStopLocatingUser:)])
        {
            [self.delegate mapViewDidStopLocatingUser:self];
        }

        [self setUserTrackingMode:VMGLUserTrackingModeNone animated:YES completionHandler:nil];

        [self.userLocationAnnotationView removeFromSuperview];
        self.userLocationAnnotationView = nil;
    }
}

- (void)setUserLocationAnnotationView:(VMGLUserLocationAnnotationView *)newAnnotationView
{
    if ( ! [newAnnotationView isEqual:_userLocationAnnotationView])
    {
        _userLocationAnnotationView = newAnnotationView;
        [self updateUserLocationAnnotationView];
    }
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingUserLocation
{
    return [NSSet setWithObject:@"userLocationAnnotationView"];
}

- (BOOL)isUserLocationVisible
{
    if (self.userLocationAnnotationView)
    {
        CGPoint locationPoint = [self convertCoordinate:self.userLocation.coordinate toPointToView:self];

        CGRect locationRect = CGRectMake(locationPoint.x - self.userLocation.location.horizontalAccuracy,
                                         locationPoint.y - self.userLocation.location.horizontalAccuracy,
                                         self.userLocation.location.horizontalAccuracy * 2,
                                         self.userLocation.location.horizontalAccuracy * 2);

        return CGRectIntersectsRect([self bounds], locationRect);
    }

    return NO;
}

- (void)setUserTrackingMode:(VMGLUserTrackingMode)mode
{
    [self setUserTrackingMode:mode animated:YES completionHandler:nil];
}

- (void)setUserTrackingMode:(VMGLUserTrackingMode)mode animated:(BOOL)animated
{
    [self setUserTrackingMode:mode animated:animated completionHandler:nil];
}

- (void)setUserTrackingMode:(VMGLUserTrackingMode)mode animated:(BOOL)animated completionHandler:(nullable void (^)(void))completion
{
    MGLLogDebug(@"Setting userTrackingMode: %lu animated: %@", mode, VMGLStringFromBOOL(animated));
    if (mode == _userTrackingMode)
    {
        if (completion)
        {
            completion();
        }
        return;
    }

    VMGLUserTrackingMode oldMode = _userTrackingMode;
    [self willChangeValueForKey:@"userTrackingMode"];
    _userTrackingMode = mode;
    [self didChangeValueForKey:@"userTrackingMode"];

    switch (_userTrackingMode)
    {
        case VMGLUserTrackingModeNone:
        {
            self.userTrackingState = VMGLUserTrackingStatePossible;

            // Immediately update the annotation view; other cases update inside
            // the locationManager:didUpdateLocations: method.
            [self updateUserLocationAnnotationView];

            break;
        }
        case VMGLUserTrackingModeFollow:
        case VMGLUserTrackingModeFollowWithCourse:
        {
            self.userTrackingState = animated ? VMGLUserTrackingStatePossible : VMGLUserTrackingStateChanged;
            self.showsUserLocation = YES;

            break;
        }
        case VMGLUserTrackingModeFollowWithHeading:
        {
            if (oldMode == VMGLUserTrackingModeNone)
            {
                self.userTrackingState = animated ? VMGLUserTrackingStatePossible : VMGLUserTrackingStateChanged;
            }

            self.showsUserLocation = YES;

            if (self.zoomLevel < self.currentMinimumZoom)
            {
                [self setZoomLevel:self.currentMinimumZoom animated:YES];
            }

            break;
        }
    }

    CLLocation *location;
    if (_userTrackingMode != VMGLUserTrackingModeNone && (location = self.userLocation.location) && self.userLocationAnnotationView)
    {
        [self locationManager:self.locationManager didUpdateLocations:@[location] animated:animated completionHandler:completion];
    }
    else if (completion)
    {
        completion();
    }

    [self validateUserHeadingUpdating];

    if ([self.delegate respondsToSelector:@selector(mapView:didChangeUserTrackingMode:animated:)])
    {
        [self.delegate mapView:self didChangeUserTrackingMode:_userTrackingMode animated:animated];
    }
}

- (void)setUserLocationVerticalAlignment:(VMGLAnnotationVerticalAlignment)alignment
{
    [self setUserLocationVerticalAlignment:alignment animated:YES];
}

- (void)setUserLocationVerticalAlignment:(VMGLAnnotationVerticalAlignment)alignment animated:(BOOL)animated
{
    _userLocationVerticalAlignment = alignment;
    if (self.userTrackingMode != VMGLUserTrackingModeNone)
    {
        CLLocation *location = self.userLocation.location;
        if (location)
        {
            [self locationManager:self.locationManager didUpdateLocations:@[location] animated:animated completionHandler:nil];
        }
    }
}

- (void)setTargetCoordinate:(CLLocationCoordinate2D)targetCoordinate
{
    [self setTargetCoordinate:targetCoordinate animated:YES completionHandler:nil];
}

- (void)setTargetCoordinate:(CLLocationCoordinate2D)targetCoordinate animated:(BOOL)animated
{
    [self setTargetCoordinate:targetCoordinate animated:animated completionHandler:nil];
}

- (void)setTargetCoordinate:(CLLocationCoordinate2D)targetCoordinate animated:(BOOL)animated completionHandler:(nullable void (^)(void))completion
{
    MGLLogDebug(@"Setting targetCoordinate: %@ animated: %@", VMGLStringFromCLLocationCoordinate2D(targetCoordinate), VMGLStringFromBOOL(animated));
    BOOL isSynchronous = YES;
    if (targetCoordinate.latitude != self.targetCoordinate.latitude
        || targetCoordinate.longitude != self.targetCoordinate.longitude)
    {
        _targetCoordinate = targetCoordinate;
        if (self.userTrackingMode == VMGLUserTrackingModeFollowWithCourse)
        {
            self.userTrackingState = VMGLUserTrackingStatePossible;

            if (CLLocation *location = self.userLocation.location)
            {
                isSynchronous = NO;
                [self locationManager:self.locationManager didUpdateLocations:@[location] animated:animated completionHandler:completion];
            }
        }
    }
    if (isSynchronous && completion)
    {
        completion();
    }
}

- (void)setShowsUserHeadingIndicator:(BOOL)showsUserHeadingIndicator
{
    MGLLogDebug(@"Setting showsUserHeadingIndicator: %@", VMGLStringFromBOOL(showsUserHeadingIndicator));
    _showsUserHeadingIndicator = showsUserHeadingIndicator;

    if (_showsUserHeadingIndicator)
    {
        self.showsUserLocation = YES;
    }
    [self validateUserHeadingUpdating];
}

- (void)validateUserHeadingUpdating
{
    BOOL canShowPermanentHeadingIndicator = self.showsUserHeadingIndicator && self.userTrackingMode != VMGLUserTrackingModeFollowWithCourse;

    if (canShowPermanentHeadingIndicator || self.userTrackingMode == VMGLUserTrackingModeFollowWithHeading)
    {
        [self updateHeadingForDeviceOrientation];
        [self.locationManager startUpdatingHeading];
    }
    else
    {
        [self.locationManager stopUpdatingHeading];
    }
}

- (void)locationManager:(id<VMGLLocationManager>)manager didUpdateLocations:(NSArray *)locations
{
    [self locationManager:manager didUpdateLocations:locations animated:YES completionHandler:nil];
}

- (void)locationManager:(__unused id<VMGLLocationManager>)manager didUpdateLocations:(NSArray *)locations animated:(BOOL)animated completionHandler:(nullable void (^)(void))completion
{
    CLLocation *oldLocation = self.userLocation.location;
    CLLocation *newLocation = locations.lastObject;
    _distanceFromOldUserLocation = [newLocation distanceFromLocation:oldLocation];

    if ( ! _showsUserLocation || ! newLocation || ! CLLocationCoordinate2DIsValid(newLocation.coordinate)) return;

    if (! oldLocation || ! CLLocationCoordinate2DIsValid(oldLocation.coordinate) || [newLocation distanceFromLocation:oldLocation]
        || oldLocation.course != newLocation.course)
    {
        if ( ! oldLocation || ! CLLocationCoordinate2DIsValid(oldLocation.coordinate) || self.userTrackingState != VMGLUserTrackingStateBegan)
        {
            self.userLocation.location = newLocation;
        }

        if ([self.delegate respondsToSelector:@selector(mapView:didUpdateUserLocation:)])
        {
            [self.delegate mapView:self didUpdateUserLocation:self.userLocation];
        }
    }

    [self didUpdateLocationWithUserTrackingAnimated:animated completionHandler:completion];

    NSTimeInterval duration = VMGLAnimationDuration;
    if (oldLocation && ! CGPointEqualToPoint(self.userLocationAnnotationView.center, CGPointZero))
    {
        duration = MIN([newLocation.timestamp timeIntervalSinceDate:oldLocation.timestamp], VMGLUserLocationAnimationDuration);
    }
    [self updateUserLocationAnnotationViewAnimatedWithDuration:duration];

    if (self.userTrackingMode == VMGLUserTrackingModeNone &&
        self.userLocationAnnotationView.accessibilityElementIsFocused &&
        [UIApplication sharedApplication].applicationState == UIApplicationStateActive)
    {
        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self.userLocationAnnotationView);
    }
}

- (void)didUpdateLocationWithUserTrackingAnimated:(BOOL)animated completionHandler:(nullable void (^)(void))completion
{
    CLLocation *location = self.userLocation.location;
    if ( ! _showsUserLocation || ! location
        || ! CLLocationCoordinate2DIsValid(location.coordinate)
        || self.userTrackingMode == VMGLUserTrackingModeNone)
    {
        if (completion)
        {
            completion();
        }
        return;
    }

    // If the user location annotation is already where it’s supposed to be,
    // don’t change the viewport.
    CGPoint correctPoint = self.userLocationAnnotationViewCenter;
    CGPoint currentPoint = [self convertCoordinate:self.userLocation.coordinate toPointToView:self];
    if (std::abs(currentPoint.x - correctPoint.x) <= 1.0 && std::abs(currentPoint.y - correctPoint.y) <= 1.0
        && self.userTrackingMode != VMGLUserTrackingModeFollowWithCourse)
    {
        if (completion)
        {
            completion();
        }
        return;
    }

    if (self.userTrackingMode == VMGLUserTrackingModeFollowWithCourse
        && CLLocationCoordinate2DIsValid(self.targetCoordinate))
    {
        if (self.userTrackingState != VMGLUserTrackingStateBegan)
        {
            // Keep both the user and the destination in view.
            [self didUpdateLocationWithTargetAnimated:animated completionHandler:completion];
        }
    }
    else if (self.userTrackingState == VMGLUserTrackingStatePossible)
    {
        // The first location update is often a great distance away from the
        // current viewport, so fly there to provide additional context.
        [self didUpdateLocationSignificantlyAnimated:animated completionHandler:completion];
    }
    else if (self.userTrackingState == VMGLUserTrackingStateChanged)
    {
        // Subsequent updates get a more subtle animation.
        [self didUpdateLocationIncrementallyAnimated:animated completionHandler:completion];
    }
    [self unrotateIfNeededAnimated:YES];
}

/// Changes the viewport based on an incremental location update.
- (void)didUpdateLocationIncrementallyAnimated:(BOOL)animated completionHandler:(nullable void (^)(void))completion
{
    [self _setCenterCoordinate:self.userLocation.location.coordinate
                   edgePadding:self.edgePaddingForFollowing
                     zoomLevel:self.zoomLevel
                     direction:self.directionByFollowingWithCourse
                      duration:animated ? VMGLUserLocationAnimationDuration : 0
       animationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]
             completionHandler:completion];
}

/// Changes the viewport based on a significant location update, such as the
/// first location update.
- (void)didUpdateLocationSignificantlyAnimated:(BOOL)animated completionHandler:(nullable void (^)(void))completion
{
    
    if (_distanceFromOldUserLocation >= VMGLDistanceThresholdForCameraPause) {
        self.userTrackingState = VMGLUserTrackingStateBeginSignificantTransition;
    } else {
        self.userTrackingState = VMGLUserTrackingStateBegan;
    }

    VMGLMapCamera *camera = self.camera;
    camera.centerCoordinate = self.userLocation.location.coordinate;
    camera.heading = self.directionByFollowingWithCourse;
    if (self.zoomLevel < VMGLMinimumZoomLevelForUserTracking)
    {
        camera.altitude = MGLAltitudeForZoomLevel(VMGLDefaultZoomLevelForUserTracking,
                                                  camera.pitch,
                                                  camera.centerCoordinate.latitude,
                                                  self.frame.size);
    }

    __weak VMGLMapView *weakSelf = self;
    [self _flyToCamera:camera
           edgePadding:self.edgePaddingForFollowing
          withDuration:animated ? -1 : 0
          peakAltitude:-1
     completionHandler:^{
        VMGLMapView *strongSelf = weakSelf;
        if (strongSelf.userTrackingState == VMGLUserTrackingStateBegan ||
            strongSelf.userTrackingState == VMGLDistanceThresholdForCameraPause)
        {
            strongSelf.userTrackingState = VMGLUserTrackingStateChanged;
        }
        if (completion)
        {
            completion();
        }
    }];
}

/// Changes the viewport based on a location update in the presence of a target
/// coordinate that must also be displayed on the map concurrently.
- (void)didUpdateLocationWithTargetAnimated:(BOOL)animated completionHandler:(nullable void (^)(void))completion
{
    BOOL firstUpdate = self.userTrackingState == VMGLUserTrackingStatePossible;
    void (^animationCompletion)(void);
    if (animated && firstUpdate)
    {
        self.userTrackingState = VMGLUserTrackingStateBegan;
        __weak VMGLMapView *weakSelf = self;
        animationCompletion = ^{
            VMGLMapView *strongSelf = weakSelf;
            if (strongSelf.userTrackingState == VMGLUserTrackingStateBegan)
            {
                strongSelf.userTrackingState = VMGLUserTrackingStateChanged;
            }
            if (completion)
            {
                completion();
            }
        };
    }

    CLLocationCoordinate2D foci[] = {
        self.userLocation.location.coordinate,
        self.targetCoordinate,
    };
    UIEdgeInsets inset = self.edgePaddingForFollowingWithCourse;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (self.userLocationVerticalAlignment == VMGLAnnotationVerticalAlignmentCenter)
    {
        inset.bottom = CGRectGetMaxY(self.bounds) - CGRectGetMidY(self.contentFrame);
    }
#pragma clang diagnostic pop

    [self _setVisibleCoordinates:foci
                           count:sizeof(foci) / sizeof(foci[0])
                     edgePadding:inset
                       direction:self.directionByFollowingWithCourse
                        duration:animated ? VMGLUserLocationAnimationDuration : 0
         animationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]
               completionHandler:animationCompletion];
}

/// Returns the edge padding to apply when moving the map to a tracked location.
- (UIEdgeInsets)edgePaddingForFollowing
{
    // Center on user location unless we're already centered there (or very close).
    CGPoint correctPoint = self.userLocationAnnotationViewCenter;

    // Shift the entire frame upward or downward to accommodate a shifted user
    // location annotation view.
    CGRect bounds = self.bounds;
    CGRect boundsAroundCorrectPoint = CGRectOffset(bounds,
                                                   correctPoint.x - CGRectGetMidX(bounds),
                                                   correctPoint.y - CGRectGetMidY(bounds));
    return UIEdgeInsetsMake(CGRectGetMinY(boundsAroundCorrectPoint) - CGRectGetMinY(bounds),
                            CGRectGetMaxX(boundsAroundCorrectPoint) - CGRectGetMaxX(bounds),
                            CGRectGetMaxY(bounds) - CGRectGetMaxY(boundsAroundCorrectPoint),
                            CGRectGetMaxX(bounds) - CGRectGetMaxX(boundsAroundCorrectPoint));
}

/// Returns the edge padding to apply during bifocal course tracking.
- (UIEdgeInsets)edgePaddingForFollowingWithCourse
{
    UIEdgeInsets inset = VMGLUserLocationAnnotationViewInset;
    inset.top += CGRectGetHeight(self.userLocationAnnotationView.frame);
    inset.bottom += CGRectGetHeight(self.userLocationAnnotationView.frame);
    return inset;
}

/// Returns the direction the map should be turned to due to course tracking.
- (CLLocationDirection)directionByFollowingWithCourse
{
    CLLocationDirection direction = -1;
    if (self.userTrackingMode == VMGLUserTrackingModeFollowWithCourse)
    {
        if (CLLocationCoordinate2DIsValid(self.targetCoordinate))
        {
            mbgl::LatLng userLatLng = VMGLLatLngFromLocationCoordinate2D(self.userLocation.coordinate);
            mbgl::LatLng targetLatLng = VMGLLatLngFromLocationCoordinate2D(self.targetCoordinate);
            mbgl::ProjectedMeters userMeters = mbgl::Projection::projectedMetersForLatLng(userLatLng);
            mbgl::ProjectedMeters targetMeters = mbgl::Projection::projectedMetersForLatLng(targetLatLng);
            double angle = atan2(targetMeters.easting() - userMeters.easting(),
                                 targetMeters.northing() - userMeters.northing());
            direction = mbgl::util::wrap(VMGLDegreesFromRadians(angle), 0., 360.);
        }
        else
        {
            direction = self.userLocation.location.course;
        }

        if (direction >= 0)
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            if (self.userLocationVerticalAlignment == VMGLAnnotationVerticalAlignmentTop)
            {
                direction += 180;
            }
#pragma clang diagnostic pop
        }
    }
    return direction;
}

- (BOOL)locationManagerShouldDisplayHeadingCalibration:(id<VMGLLocationManager>)manager
{
    if (self.displayHeadingCalibration) [self performSelector:@selector(dismissHeadingCalibrationDisplay:)
                                                      withObject:manager
                                                      afterDelay:10.0];

    return self.displayHeadingCalibration;
}

- (void)dismissHeadingCalibrationDisplay:(id<VMGLLocationManager>)manager
{
    [manager dismissHeadingCalibrationDisplay];
}

- (void)locationManager:(__unused id<VMGLLocationManager>)manager didUpdateHeading:(CLHeading *)newHeading
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        if ( ! self->_showsUserLocation || self.pan.state == UIGestureRecognizerStateBegan || newHeading.headingAccuracy < 0) return;

        self.userLocation.heading = newHeading;

        if (self.showsUserHeadingIndicator || self.userTrackingMode == VMGLUserTrackingModeFollowWithHeading)
        {
            [self updateUserLocationAnnotationView];
        }

        if ([self.delegate respondsToSelector:@selector(mapView:didUpdateUserLocation:)])
        {
            [self.delegate mapView:self didUpdateUserLocation:self.userLocation];

            if (!self->_showsUserLocation) return;
        }

        CLLocationDirection headingDirection = (newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading);

        if (headingDirection >= 0 && self.userTrackingMode == VMGLUserTrackingModeFollowWithHeading
            && self.userTrackingState != VMGLUserTrackingStateBegan)
        {
            [self _setDirection:headingDirection animated:YES];
            [self updateUserLocationAnnotationView];
        }
    });
}

- (void)locationManager:(__unused id<VMGLLocationManager>)manager didFailWithError:(NSError *)error
{
    if ([error code] == kCLErrorDenied)
    {
        self.userTrackingMode  = VMGLUserTrackingModeNone;
        self.showsUserLocation = NO;

        if ([self.delegate respondsToSelector:@selector(mapView:didFailToLocateUserWithError:)])
        {
            [self.delegate mapView:self didFailToLocateUserWithError:error];
        }
    }
}

- (void)locationManagerDidChangeAuthorization:(id<VMGLLocationManager>)manager
{
    if (![self shouldShowLocationDotBasedOnCurrentLocationPermissions])
    {
        [self.userLocationAnnotationView removeFromSuperview];
        [self.locationManager stopUpdatingLocation];
        [self.locationManager stopUpdatingHeading];
    } else {
        if (@available(iOS 14, *)) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140000
            if (self.userTrackingMode != VMGLUserTrackingModeNone &&
                [manager respondsToSelector:@selector(authorizationStatus)] &&
                (manager.authorizationStatus != kCLAuthorizationStatusRestricted ||
                 manager.authorizationStatus != kCLAuthorizationStatusAuthorizedAlways ||
                 manager.authorizationStatus != kCLAuthorizationStatusAuthorizedWhenInUse) &&
                [manager respondsToSelector:@selector(accuracyAuthorization)] &&
                manager.accuracyAuthorization == CLAccuracyAuthorizationReducedAccuracy &&
                [self accuracyDescriptionString] != nil ) {
                [self.locationManager requestTemporaryFullAccuracyAuthorizationWithPurposeKey:@"MGLAccuracyAuthorizationDescription"];
            } else {
                [self validateLocationServices];
            }
#endif
        } else {
            [self validateLocationServices];
        }
    }
    
    if (@available(iOS 14, *)) {
        if ([self.delegate respondsToSelector:@selector(mapView:didChangeLocationManagerAuthorization:)]) {
            [self.delegate mapView:self didChangeLocationManagerAuthorization:manager];
        }
    }
}

- (BOOL)shouldShowLocationDotBasedOnCurrentLocationPermissions
{
    return self.locationManager && (self.locationManager.authorizationStatus == kCLAuthorizationStatusAuthorizedAlways
                                    || self.locationManager.authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse);
}

- (void)updateHeadingForDeviceOrientation
{
    if (self.locationManager)
    {
        // note that right/left device and interface orientations are opposites (see UIApplication.h)
        //
        CLDeviceOrientation orientation;
        switch ([[UIApplication sharedApplication] statusBarOrientation])
        {
            case (UIInterfaceOrientationLandscapeLeft):
            {
                orientation = CLDeviceOrientationLandscapeRight;
                break;
            }
            case (UIInterfaceOrientationLandscapeRight):
            {
                orientation = CLDeviceOrientationLandscapeLeft;
                break;
            }
            case (UIInterfaceOrientationPortraitUpsideDown):
            {
                orientation = CLDeviceOrientationPortraitUpsideDown;
                break;
            }
            case (UIInterfaceOrientationPortrait):
            default:
            {
                orientation = CLDeviceOrientationPortrait;
                break;
            }
        }

        // Setting the location manager's heading orientation causes it to send
        // a heading event, which in turn makes us redraw, which kicks off a
        // loop... so don't do that. rdar://34059173
        if (self.locationManager.headingOrientation != orientation)
        {
            self.locationManager.headingOrientation = orientation;
        }
    }
}

#pragma mark Data

- (NSArray<id <VMGLFeature>> *)visibleFeaturesAtPoint:(CGPoint)point
{
    MGLLogDebug(@"Querying visibleFeaturesAtPoint: %@", NSStringFromCGPoint(point));
    return [self visibleFeaturesAtPoint:point inStyleLayersWithIdentifiers:nil];
}

- (NSArray<id <VMGLFeature>> *)visibleFeaturesAtPoint:(CGPoint)point inStyleLayersWithIdentifiers:(NSSet<NSString *> *)styleLayerIdentifiers {
    MGLLogDebug(@"Querying visibleFeaturesAtPoint: %@ inStyleLayersWithIdentifiers: %@", NSStringFromCGPoint(point), styleLayerIdentifiers);
    return [self visibleFeaturesAtPoint:point inStyleLayersWithIdentifiers:styleLayerIdentifiers predicate:nil];
}

- (NSArray<id <VMGLFeature>> *)visibleFeaturesAtPoint:(CGPoint)point inStyleLayersWithIdentifiers:(NSSet<NSString *> *)styleLayerIdentifiers predicate:(NSPredicate *)predicate
{
    MGLLogDebug(@"Querying visibleFeaturesAtPoint: %@ inStyleLayersWithIdentifiers: %@ predicate: %@", NSStringFromCGPoint(point), styleLayerIdentifiers, predicate);
    mbgl::ScreenCoordinate screenCoordinate = { point.x, point.y };

    mbgl::optional<std::vector<std::string>> optionalLayerIDs;
    if (styleLayerIdentifiers)
    {
        __block std::vector<std::string> layerIDs;
        layerIDs.reserve(styleLayerIdentifiers.count);
        [styleLayerIdentifiers enumerateObjectsUsingBlock:^(NSString * _Nonnull identifier, BOOL * _Nonnull stop)
        {
            layerIDs.push_back(identifier.UTF8String);
        }];
        optionalLayerIDs = layerIDs;
    }
    
    mbgl::optional<mbgl::style::Filter> optionalFilter;
    if (predicate) {
        optionalFilter = predicate.mgl_filter;
    }

    std::vector<mbgl::Feature> features = _rendererFrontend->getRenderer()->queryRenderedFeatures(screenCoordinate, { optionalLayerIDs, optionalFilter });
    return MGLFeaturesFromMBGLFeatures(features);
}

- (NSArray<id <VMGLFeature>> *)visibleFeaturesInRect:(CGRect)rect {
    MGLLogDebug(@"Querying visibleFeaturesInRect: %@", NSStringFromCGRect(rect));
    return [self visibleFeaturesInRect:rect inStyleLayersWithIdentifiers:nil];
}

- (NSArray<id <VMGLFeature>> *)visibleFeaturesInRect:(CGRect)rect inStyleLayersWithIdentifiers:(NSSet<NSString *> *)styleLayerIdentifiers {
    MGLLogDebug(@"Querying visibleFeaturesInRect: %@ inStyleLayersWithIdentifiers: %@", NSStringFromCGRect(rect), styleLayerIdentifiers);
    return [self visibleFeaturesInRect:rect inStyleLayersWithIdentifiers:styleLayerIdentifiers predicate:nil];
}

- (NSArray<id <VMGLFeature>> *)visibleFeaturesInRect:(CGRect)rect inStyleLayersWithIdentifiers:(NSSet<NSString *> *)styleLayerIdentifiers predicate:(NSPredicate *)predicate {
    MGLLogDebug(@"Querying visibleFeaturesInRect: %@ inStyleLayersWithIdentifiers: %@ predicate: %@", NSStringFromCGRect(rect), styleLayerIdentifiers, predicate);
    mbgl::ScreenBox screenBox = {
        { CGRectGetMinX(rect), CGRectGetMinY(rect) },
        { CGRectGetMaxX(rect), CGRectGetMaxY(rect) },
    };

    mbgl::optional<std::vector<std::string>> optionalLayerIDs;
    if (styleLayerIdentifiers) {
        __block std::vector<std::string> layerIDs;
        layerIDs.reserve(styleLayerIdentifiers.count);
        [styleLayerIdentifiers enumerateObjectsUsingBlock:^(NSString * _Nonnull identifier, BOOL * _Nonnull stop) {
            layerIDs.push_back(identifier.UTF8String);
        }];
        optionalLayerIDs = layerIDs;
    }
    
    mbgl::optional<mbgl::style::Filter> optionalFilter;
    if (predicate) {
        optionalFilter = predicate.mgl_filter;
    }

    std::vector<mbgl::Feature> features = _rendererFrontend->getRenderer()->queryRenderedFeatures(screenBox, { optionalLayerIDs, optionalFilter });
    return MGLFeaturesFromMBGLFeatures(features);
}

#pragma mark - Utility -

- (void)animateWithDelay:(NSTimeInterval)delay animations:(void (^)(void))animations
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), animations);
}

- (CGFloat)currentMinimumZoom
{
    return fmaxf(*self.vmglMap.getBounds().minZoom, MGLMinimumZoom);
}

- (BOOL)isRotationAllowed
{
    return (self.zoomLevel >= self.currentMinimumZoom);
}

- (void)unrotateIfNeededForGesture
{
    // Avoid contention with in-progress gestures.
    UIGestureRecognizerState state = self.pinch.state;
    if (self.direction != 0
        && state != UIGestureRecognizerStateBegan
        && state != UIGestureRecognizerStateChanged)
    {
        [self unrotateIfNeededAnimated:YES];

        // Snap to north.
        if ((self.direction < VMGLToleranceForSnappingToNorth
             || self.direction > 360 - VMGLToleranceForSnappingToNorth)
            && self.userTrackingMode != VMGLUserTrackingModeFollowWithHeading
            && self.userTrackingMode != VMGLUserTrackingModeFollowWithCourse)
        {
            [self resetNorthAnimated:YES];
        }
    }
}

/// Rotate back to true north if the map view is zoomed too far out.
- (void)unrotateIfNeededAnimated:(BOOL)animated
{
    if (self.direction != 0 && ! self.isRotationAllowed
        && self.userTrackingState != VMGLUserTrackingStateBegan)
    {
        if (animated)
        {
            self.userInteractionEnabled = NO;

            __weak VMGLMapView *weakSelf = self;

            [self animateWithDelay:0.1 animations:^
            {
                [weakSelf resetNorthAnimated:YES];

                [self animateWithDelay:VMGLAnimationDuration animations:^
                {
                    weakSelf.userInteractionEnabled = YES;
                }];

            }];
        }
        else
        {
            [self resetNorthAnimated:NO];
        }
    }
}

- (void)cameraWillChangeAnimated:(BOOL)animated {
    if (!_mbglMap)
    {
        return;
    }

    if ( ! _userLocationAnnotationIsSelected
            || self.userTrackingMode == VMGLUserTrackingModeNone
            || self.userTrackingState != VMGLUserTrackingStateChanged)
    {
        UIView<VMGLCalloutView> *calloutView = self.calloutViewForSelectedAnnotation;
        BOOL dismissesAutomatically = (calloutView
                && [calloutView respondsToSelector:@selector(dismissesAutomatically)]
                && calloutView.dismissesAutomatically);
        // dismissesAutomatically is an optional property and we want to dismiss
        // the callout view if it's unimplemented.
        if (dismissesAutomatically || (calloutView && ![calloutView respondsToSelector:@selector(dismissesAutomatically)]))
        {
            [self deselectAnnotation:self.selectedAnnotation animated:NO];
        }
    }

    if ( ! [self isSuppressingChangeDelimiters] )
    {
        if ([self.delegate respondsToSelector:@selector(mapView:regionWillChangeWithReason:animated:)])
        {
            [self.delegate mapView:self regionWillChangeWithReason:self.cameraChangeReasonBitmask animated:animated];
        }
        else if ([self.delegate respondsToSelector:@selector(mapView:regionWillChangeAnimated:)])
        {
            [self.delegate mapView:self regionWillChangeAnimated:animated];
        }
    }
}

- (void)cameraIsChanging {
    if (!_mbglMap)
    {
        return;
    }

    [self updateCompass];
    [self updateScaleBar];

    if ([self.delegate respondsToSelector:@selector(mapView:regionIsChangingWithReason:)])
    {
        [self.delegate mapView:self regionIsChangingWithReason:self.cameraChangeReasonBitmask];
    }
    else if ([self.delegate respondsToSelector:@selector(mapViewRegionIsChanging:)])
    {
        [self.delegate mapViewRegionIsChanging:self];
    }
}

- (void)cameraDidChangeAnimated:(BOOL)animated {
    if (!_mbglMap)
    {
        return;
    }

    [self updateCompass];
    [self updateScaleBar];

    if ( ! [self isSuppressingChangeDelimiters])
    {
        BOOL respondsToSelector = [self.delegate respondsToSelector:@selector(mapView:regionDidChangeAnimated:)];
        BOOL respondsToSelectorWithReason = [self.delegate respondsToSelector:@selector(mapView:regionDidChangeWithReason:animated:)];

        if ((respondsToSelector || respondsToSelectorWithReason) &&
            ([UIApplication sharedApplication].applicationState == UIApplicationStateActive))
        {
            _featureAccessibilityElements = nil;
            _visiblePlaceFeatures = nil;
            _visibleRoadFeatures = nil;
            if (_accessibilityValueAnnouncementIsPending) {
                _accessibilityValueAnnouncementIsPending = NO;
                [self performSelector:@selector(announceAccessibilityValue) withObject:nil afterDelay:0.1];
            } else {
                UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
            }
        }

        if (respondsToSelectorWithReason)
        {
            [self.delegate mapView:self regionDidChangeWithReason:self.cameraChangeReasonBitmask animated:animated];
        }
        else if (respondsToSelector)
        {
            [self.delegate mapView:self regionDidChangeAnimated:animated];
        }

        [self resetCameraChangeReason];
    }
}

- (void)announceAccessibilityValue
{
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, self.accessibilityValue);
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

- (void)mapViewWillStartLoadingMap {
    if (!_mbglMap)
    {
        return;
    }

    if ([self.delegate respondsToSelector:@selector(mapViewWillStartLoadingMap:)])
    {
        [self.delegate mapViewWillStartLoadingMap:self];
    }
}

- (void)mapViewDidFinishLoadingMap {
    if (!_mbglMap)
    {
        return;
    }

    [self.style willChangeValueForKey:@"sources"];
    [self.style didChangeValueForKey:@"sources"];
    [self.style willChangeValueForKey:@"layers"];
    [self.style didChangeValueForKey:@"layers"];
    if ([self.delegate respondsToSelector:@selector(mapViewDidFinishLoadingMap:)])
    {
        [self.delegate mapViewDidFinishLoadingMap:self];
    }
}

- (void)mapViewDidFailLoadingMapWithError:(NSError *)error {
    if (!_mbglMap)
    {
        return;
    }

    if ([self.delegate respondsToSelector:@selector(mapViewDidFailLoadingMap:withError:)])
    {
        [self.delegate mapViewDidFailLoadingMap:self withError:error];
    }
}

- (void)mapViewWillStartRenderingFrame {
    [self cancelBackgroundSnapshot];

    if (!_mbglMap)
    {
        return;
    }

    if ([self.delegate respondsToSelector:@selector(mapViewWillStartRenderingFrame:)])
    {
        [self.delegate mapViewWillStartRenderingFrame:self];
    }
}

- (void)mapViewDidFinishRenderingFrameFullyRendered:(BOOL)fullyRendered {
    if (!_mbglMap)
    {
        return;
    }

    if (_isChangingAnnotationLayers)
    {
        _isChangingAnnotationLayers = NO;
        [self.style didChangeValueForKey:@"layers"];
    }

    if ([self.delegate respondsToSelector:@selector(mapViewDidFinishRenderingFrame:fullyRendered:)])
    {
        [self.delegate mapViewDidFinishRenderingFrame:self fullyRendered:fullyRendered];
    }
}

- (void)mapViewWillStartRenderingMap {
    if (!_mbglMap)
    {
        return;
    }

    if ([self.delegate respondsToSelector:@selector(mapViewWillStartRenderingMap:)])
    {
        [self.delegate mapViewWillStartRenderingMap:self];
    }
}

- (void)mapViewDidFinishRenderingMapFullyRendered:(BOOL)fullyRendered {
    if (!_mbglMap)
    {
        return;
    }
    
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);

    if ([self.delegate respondsToSelector:@selector(mapViewDidFinishRenderingMap:fullyRendered:)])
    {
        [self.delegate mapViewDidFinishRenderingMap:self fullyRendered:fullyRendered];
    }
}

- (void)mapViewDidBecomeIdle {
    if (!_mbglMap) {
        return;
    }

#ifdef MBGL_ENABLE_MAP_SNAPSHOTS
    [self queueBackgroundSnapshot];
#endif

    if ([self.delegate respondsToSelector:@selector(mapViewDidBecomeIdle:)]) {
        [self.delegate mapViewDidBecomeIdle:self];
    }
}

- (void)mapViewDidFinishLoadingStyle {
    if (!_mbglMap)
    {
        return;
    }

    self.style = [[VMGLStyle alloc] initWithRawStyle:&self.vmglMap.getStyle() stylable:self];
    if ([self.delegate respondsToSelector:@selector(mapView:didFinishLoadingStyle:)])
    {
        [self.delegate mapView:self didFinishLoadingStyle:self.style];
    }
}

- (void)sourceDidChange:(VMGLSource *)source {
    // no-op: we only show attribution after tapping the info button, so there's no
    // interactive update needed.
}

- (void)didFailToLoadImage:(NSString *)imageName {

    if ([self.delegate respondsToSelector:@selector(mapView:didFailToLoadImage:)]) {
        MGLImage *imageToLoad = [self.delegate mapView:self didFailToLoadImage:imageName];
        if (imageToLoad) {
            auto image = [imageToLoad mgl_styleImageWithIdentifier:imageName];
            self.vmglMap.getStyle().addImage(std::move(image));
        }
    }
}

- (BOOL)shouldRemoveStyleImage:(NSString *)imageName {
    if ([self.delegate respondsToSelector:@selector(mapView:shouldRemoveStyleImage:)]) {
        return [self.delegate mapView:self shouldRemoveStyleImage:imageName];
    }
    
    return YES;
}

- (void)updateUserLocationAnnotationView
{
    [self updateUserLocationAnnotationViewAnimatedWithDuration:0];
}

- (void)updateAnnotationViews
{
    BOOL delegateImplementsViewForAnnotation = [self.delegate respondsToSelector:@selector(mapView:viewForAnnotation:)];

    if (!delegateImplementsViewForAnnotation)
    {
        return;
    }

    // If the map is pitched consider the viewport to be exactly the same as the bounds.
    // Otherwise, add a small buffer.
    CGFloat largestWidth = MAX(_largestAnnotationViewSize.width, CGRectGetWidth(self.frame));
    CGFloat largestHeight = MAX(_largestAnnotationViewSize.height, CGRectGetHeight(self.frame));
    CGFloat widthAdjustment = self.camera.pitch > 0.0 ? 0.0 : -largestWidth * 2.0;
    CGFloat heightAdjustment = self.camera.pitch > 0.0 ? 0.0 : -largestHeight * 2.0;
    CGRect viewPort = CGRectInset(self.bounds, widthAdjustment, heightAdjustment);

    NSArray *visibleAnnotations = [self visibleAnnotationsInRect:viewPort];
    NSMutableArray *offscreenAnnotations = [self.annotations mutableCopy];
    [offscreenAnnotations removeObjectsInArray:visibleAnnotations];

    // Update the center of visible annotation views
    for (id<VMGLAnnotation> annotation in visibleAnnotations)
    {
        // Defer to the shape/polygon styling delegate methods
        if ([annotation isKindOfClass:[VMGLMultiPoint class]])
        {
            continue;
        }

        // Get the annotation tag then use it to get the context.
        VMGLAnnotationTag annotationTag = [self annotationTagForAnnotation:annotation];
        MGLAssert(annotationTag != VMGLAnnotationTagNotFound, @"-visibleAnnotationsInRect: returned unrecognized annotation");
        VMGLAnnotationContext &annotationContext = _annotationContextsByAnnotationTag.at(annotationTag);

        VMGLAnnotationView *annotationView = annotationContext.annotationView;
        if (!annotationView)
        {
            // This will dequeue views if the delegate implements the dequeue call
            annotationView = [self annotationViewForAnnotation:annotationContext.annotation];

            if (annotationView)
            {
                annotationView.mapView = self;
                annotationContext.annotationView = annotationView;

                // New annotation (created because there is nothing to dequeue) may not have been added to the
                // container view yet. Add them here.
                if (!annotationView.superview) {
                    [self.annotationContainerView insertSubview:annotationView atIndex:0];
                }
            }
        }

        if (annotationView)
        {
            annotationView.center = VMGLPointRounded([self convertCoordinate:annotationContext.annotation.coordinate toPointToView:self]);
        }
    }

    VMGLCoordinateBounds coordinateBounds = [self convertRect:viewPort toCoordinateBoundsFromView:self];

    // Enqueue (and move if required) offscreen annotation views
    for (id<VMGLAnnotation> annotation in offscreenAnnotations)
    {
        // Defer to the shape/polygon styling delegate methods
        if ([annotation isKindOfClass:[VMGLMultiPoint class]])
        {
            continue;
        }

        VMGLAnnotationTag annotationTag = [self annotationTagForAnnotation:annotation];
        MGLAssert(annotationTag != VMGLAnnotationTagNotFound, @"-visibleAnnotationsInRect: returned unrecognized annotation");
        VMGLAnnotationContext &annotationContext = _annotationContextsByAnnotationTag.at(annotationTag);
        UIView *annotationView = annotationContext.annotationView;

        if (annotationView)
        {
            CLLocationCoordinate2D coordinate = annotation.coordinate;
            // Every so often (1 out of 1000 frames?) the mbgl query mechanism fails. This logic spot checks the
            // offscreenAnnotations values -- if they are actually still on screen then the view center is
            // moved and the enqueue operation is avoided. This allows us to keep the performance benefit of
            // using the mbgl query result. It also forces views that have just gone offscreen to be cleared
            // fully from view.
            if (VMGLCoordinateInCoordinateBounds(coordinate, coordinateBounds))
            {
                annotationView.center = [self convertCoordinate:annotationContext.annotation.coordinate toPointToView:self];
            }
            else
            {
                if (annotationView.layer.animationKeys.count > 0) {
                    continue;
                }

                // Move the annotation view far out of view to the left
                CGPoint adjustedCenter = annotationView.center;
                adjustedCenter.x = -CGRectGetWidth(self.frame) * 10.0;
                annotationView.center = adjustedCenter;

                [self enqueueAnnotationViewForAnnotationContext:annotationContext];
            }
        }
    }
}

- (BOOL)hasAnAnchoredAnnotationCalloutView
{
    // TODO: Remove duplicate code.
    UIView <VMGLCalloutView> *calloutView = self.calloutViewForSelectedAnnotation;
    id <VMGLAnnotation> annotation = calloutView.representedObject;
    
    BOOL isAnchoredToAnnotation = (calloutView
                                   && annotation
                                   && [calloutView respondsToSelector:@selector(isAnchoredToAnnotation)]
                                   && calloutView.isAnchoredToAnnotation);
    return isAnchoredToAnnotation;
}

- (void)updateCalloutView
{
    UIView <VMGLCalloutView> *calloutView = self.calloutViewForSelectedAnnotation;
    id <VMGLAnnotation> annotation = calloutView.representedObject;

    BOOL isAnchoredToAnnotation = (calloutView
                                   && annotation
                                   && [calloutView respondsToSelector:@selector(isAnchoredToAnnotation)]
                                   && calloutView.isAnchoredToAnnotation);

    if (isAnchoredToAnnotation)
    {
        VMGLAnnotationTag tag = [self annotationTagForAnnotation:annotation];
        VMGLAnnotationView *annotationView = nil;

        if (tag != VMGLAnnotationTagNotFound) {
            VMGLAnnotationContext &annotationContext = _annotationContextsByAnnotationTag.at(tag);
            annotationView = annotationContext.annotationView;
        } else if (annotation == self.userLocation) {
            annotationView = self.userLocationAnnotationView;
        }

        CGRect positioningRect = annotationView ?
            annotationView.frame :
            [self positioningRectForCalloutForAnnotationWithTag:tag];

        MGLAssert( ! CGRectIsNull(positioningRect), @"Positioning rect should not be CGRectNull by this point");

        CGPoint centerPoint = CGPointMake(CGRectGetMidX(positioningRect), CGRectGetMinY(positioningRect));

        if ( ! CGPointEqualToPoint(calloutView.center, centerPoint)) {
            calloutView.center = centerPoint;
        }
    }
}

- (void)updateAttributionAlertView {
    if (self.attributionController.presentingViewController) {
        self.attributionController.popoverPresentationController.sourceRect = self.attributionButton.frame;
        switch (self.attributionButtonPosition) {
            case VMGLOrnamentPositionTopLeft:
            case VMGLOrnamentPositionTopRight:
                [self.attributionController.popoverPresentationController setPermittedArrowDirections:UIMenuControllerArrowUp];
                break;
            case VMGLOrnamentPositionBottomLeft:
            case VMGLOrnamentPositionBottomRight:
                [self.attributionController.popoverPresentationController setPermittedArrowDirections:UIMenuControllerArrowDown];
                break;
        }
        [self.attributionController.popoverPresentationController.containerView setNeedsLayout];
    }
}

- (void)enqueueAnnotationViewForAnnotationContext:(VMGLAnnotationContext &)annotationContext
{
    VMGLAnnotationView *annotationView = annotationContext.annotationView;

    if (!annotationView) return;

    if (annotationContext.viewReuseIdentifier)
    {
        annotationView.annotation = nil;
        NSMutableArray *annotationViewReuseQueue = [self annotationViewReuseQueueForIdentifier:annotationContext.viewReuseIdentifier];
        if (![annotationViewReuseQueue containsObject:annotationView])
        {
            [annotationViewReuseQueue addObject:annotationView];
            annotationContext.annotationView = nil;
        }
    }
}

- (void)updateUserLocationAnnotationViewAnimatedWithDuration:(NSTimeInterval)duration
{
    VMGLUserLocationAnnotationView *annotationView = self.userLocationAnnotationView;
    if ( ! CLLocationCoordinate2DIsValid(self.userLocation.coordinate)) {
        annotationView.hidden = YES;
        return;
    }

    CGPoint userPoint;
    if (self.userTrackingMode != VMGLUserTrackingModeNone
        && self.userTrackingState == VMGLUserTrackingStateChanged)
    {
        userPoint = self.userLocationAnnotationViewCenter;
    }
    else
    {
        userPoint = VMGLPointRounded([self convertCoordinate:self.userLocation.coordinate toPointToView:self]);
    }

    if ( ! annotationView.superview)
    {
        [_mbglView->getView() addSubview:annotationView];
        // Prevents the view from sliding in from the origin.
        annotationView.center = userPoint;
    }

    if (CGRectContainsPoint(CGRectInset(self.bounds, -VMGLAnnotationUpdateViewportOutset.width,
        -VMGLAnnotationUpdateViewportOutset.height), userPoint))
    {
        // Smoothly move the user location annotation view and callout view to
        // the new location.
        
        dispatch_block_t animation = ^{
            if (self.selectedAnnotation == self.userLocation)
            {
                UIView <VMGLCalloutView> *calloutView = self.calloutViewForSelectedAnnotation;
                calloutView.frame = CGRectOffset(calloutView.frame,
                                                 userPoint.x - annotationView.center.x,
                                                 userPoint.y - annotationView.center.y);
            }
            annotationView.center = userPoint;
        };
        
        if (duration > 0) {
            [UIView animateWithDuration:duration
                                  delay:0
                                options:(UIViewAnimationOptionCurveLinear |
                                         UIViewAnimationOptionAllowUserInteraction |
                                         UIViewAnimationOptionBeginFromCurrentState)
                             animations:animation
                             completion:NULL];
        }
        else {
            animation();
        }
        _userLocationAnimationCompletionDate = [NSDate dateWithTimeIntervalSinceNow:duration];

        annotationView.hidden = NO;
        [annotationView update];
    }
    else
    {
        // User has moved far enough outside of the viewport that showing it or
        // its callout would be useless.
        annotationView.hidden = YES;

        if (_userLocationAnnotationIsSelected)
        {
            [self deselectAnnotation:self.selectedAnnotation animated:YES];
        }
    }
}

/// Intended center point of the user location annotation view with respect to
/// the overall map view (but respecting the content inset).
- (CGPoint)userLocationAnnotationViewCenter
{
    if ([self.delegate respondsToSelector:@selector(mapViewUserLocationAnchorPoint:)])
    {
        CGPoint anchorPoint = [self.delegate mapViewUserLocationAnchorPoint:self];
        return CGPointMake(anchorPoint.x + self.contentInset.left, anchorPoint.y + self.contentInset.top);
    }
    
    CGRect contentFrame = UIEdgeInsetsInsetRect(self.contentFrame, self.edgePaddingForFollowingWithCourse);
    
    if (CGRectIsEmpty(contentFrame))
    {
        contentFrame = self.contentFrame;
    }
    
    CGPoint center = CGPointMake(CGRectGetMidX(contentFrame), CGRectGetMidY(contentFrame));

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    switch (self.userLocationVerticalAlignment) {
        case VMGLAnnotationVerticalAlignmentCenter:
            break;
        case VMGLAnnotationVerticalAlignmentTop:
            center.y = CGRectGetMinY(contentFrame);
            break;
        case VMGLAnnotationVerticalAlignmentBottom:
            center.y = CGRectGetMaxY(contentFrame);
            break;
    }
#pragma clang diagnostic pop
    
    return center;
}

- (void)updateCompass
{
    [self.compassView updateCompass];
}

- (void)updateScaleBar
{
    // Use the `hidden` property (instead of `self.showsScale`) so that we don't
    // break developers who still rely on the <4.0.0 approach of directly
    // setting this property.
    if ( ! self.scaleBar.hidden)
    {
        [(VMGLScaleBar *)self.scaleBar setMetersPerPoint:[self metersPerPointAtLatitude:self.centerCoordinate.latitude]];
    }
}

- (BOOL)isFullyLoaded
{
    return self.vmglMap.isFullyLoaded();
}

- (void)prepareForInterfaceBuilder
{
    [super prepareForInterfaceBuilder];

    self.layer.borderColor = [UIColor colorWithRed:59/255.
                                             green:178/255.
                                              blue:208/255.
                                             alpha:0.8].CGColor;
    self.layer.borderWidth = 4;
    self.layer.backgroundColor = [UIColor whiteColor].CGColor;

    UIView *diagnosticView = [[UIView alloc] init];
    diagnosticView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:diagnosticView];

    // Headline
    UILabel *headlineLabel = [[UILabel alloc] init];
    headlineLabel.text = NSStringFromClass([self class]);
    headlineLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    headlineLabel.textAlignment = NSTextAlignmentCenter;
    headlineLabel.numberOfLines = 1;
    headlineLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [headlineLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                   forAxis:UILayoutConstraintAxisHorizontal];
    [diagnosticView addSubview:headlineLabel];

    // Explanation
    UILabel *explanationLabel = [[UILabel alloc] init];
    explanationLabel.text = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"DESIGNABLE", nil, nil, @"To display a map which requires authoriaztion here, set %@ to your API key in %@", @"Instructions in Interface Builder designable; {key}, {plist file name}"), @"MGLApiKey", @"Info.plist"];
    explanationLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    explanationLabel.numberOfLines = 0;
    explanationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [explanationLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                      forAxis:UILayoutConstraintAxisHorizontal];
    [diagnosticView addSubview:explanationLabel];

    // Link
    UIButton *linkButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [linkButton setTitle:NSLocalizedStringWithDefaultValue(@"FIRST_STEPS_URL", nil, nil, @"docs.mapbox.com/help/tutorials/first-steps-ios-sdk", @"Setup documentation URL display string; keep as short as possible") forState:UIControlStateNormal];
    linkButton.translatesAutoresizingMaskIntoConstraints = NO;
    linkButton.titleLabel.numberOfLines = 0;
    [linkButton setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                forAxis:UILayoutConstraintAxisHorizontal];
    [diagnosticView addSubview:linkButton];

    // Constraints
    NSDictionary *views = @{
        @"container": diagnosticView,
        @"headline": headlineLabel,
        @"explanation": explanationLabel,
        @"link": linkButton,
    };
    [self addConstraint:
     [NSLayoutConstraint constraintWithItem:diagnosticView
                                  attribute:NSLayoutAttributeCenterYWithinMargins
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:self
                                  attribute:NSLayoutAttributeCenterYWithinMargins
                                 multiplier:1
                                   constant:0]];
    [self addConstraint:
     [NSLayoutConstraint constraintWithItem:diagnosticView
                                  attribute:NSLayoutAttributeTopMargin
                                  relatedBy:NSLayoutRelationGreaterThanOrEqual
                                     toItem:self
                                  attribute:NSLayoutAttributeTopMargin
                                 multiplier:1
                                   constant:8]];
    [self addConstraint:
     [NSLayoutConstraint constraintWithItem:self
                                  attribute:NSLayoutAttributeBottomMargin
                                  relatedBy:NSLayoutRelationGreaterThanOrEqual
                                     toItem:diagnosticView
                                  attribute:NSLayoutAttributeBottomMargin
                                 multiplier:1
                                   constant:8]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[container(20@20)]-|"
                                             options:NSLayoutFormatAlignAllCenterY
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[headline]-[explanation]-[link]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[headline]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[explanation]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[link]|"
                                             options:0
                                             metrics:nil
                                               views:views]];
}

- (NSMutableArray<VMGLAnnotationView *> *)annotationViewReuseQueueForIdentifier:(NSString *)identifier {
    if (!_annotationViewReuseQueueByIdentifier[identifier])
    {
        _annotationViewReuseQueueByIdentifier[identifier] = [NSMutableArray array];
    }

    return _annotationViewReuseQueueByIdentifier[identifier];
}

#pragma mark - Snapshot image -

- (void)attemptBackgroundSnapshot {
    static NSTimeInterval lastSnapshotTime = 0.0;

    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        return;
    }

    NSTimeInterval now = CACurrentMediaTime();

    if (lastSnapshotTime == 0.0 || (now - lastSnapshotTime > VMGLBackgroundSnapshotImageInterval)) {
        MGLLogDebug(@"Taking snapshot");
        self.lastSnapshotImage = _mbglView->snapshot();
        lastSnapshotTime = now;
    }
}

- (void)cancelBackgroundSnapshot
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(attemptBackgroundSnapshot) object:nil];
}

- (void)queueBackgroundSnapshot {
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        return;
    }

    [self cancelBackgroundSnapshot];
    [self performSelector:@selector(attemptBackgroundSnapshot)
               withObject:nil
               afterDelay:VMGLBackgroundSnapshotImageIdleDelay];
}

@end

#pragma mark - IBAdditions methods

@implementation VMGLMapView (IBAdditions)

+ (NSSet<NSString *> *)keyPathsForValuesAffectingStyleURL__
{
    return [NSSet setWithObject:@"styleURL"];
}

- (nullable NSString *)styleURL__
{
    return self.styleURL.absoluteString;
}

- (void)setStyleURL__:(nullable NSString *)URLString
{
    URLString = [URLString stringByTrimmingCharactersInSet:
                 [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSURL *url = URLString.length ? [NSURL URLWithString:URLString] : nil;
    if (URLString.length && !url)
    {
        [NSException raise:MGLInvalidStyleURLException
                    format:@"“%@” is not a valid style URL.", URLString];
    }
    self.styleURL = url;
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingLatitude
{
    return [NSSet setWithObjects:@"centerCoordinate", @"camera", nil];
}

- (double)latitude
{
    return self.centerCoordinate.latitude;
}

- (void)setLatitude:(double)latitude
{
    if ( ! isnan(_pendingLongitude))
    {
        self.centerCoordinate = CLLocationCoordinate2DMake(latitude, _pendingLongitude);
        _pendingLatitude = NAN;
        _pendingLongitude = NAN;
    }
    else
    {
        // Not enough info to make a valid center coordinate yet. Stash this
        // latitude away until the longitude is set too.
        _pendingLatitude = latitude;
    }
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingLongitude
{
    return [NSSet setWithObjects:@"centerCoordinate", @"camera", nil];
}

- (double)longitude
{
    return self.centerCoordinate.longitude;
}

- (void)setLongitude:(double)longitude
{
    if ( ! isnan(_pendingLatitude))
    {
        self.centerCoordinate = CLLocationCoordinate2DMake(_pendingLatitude, longitude);
        _pendingLatitude = NAN;
        _pendingLongitude = NAN;
    }
    else
    {
        // Not enough info to make a valid center coordinate yet. Stash this
        // longitude away until the latitude is set too.
        _pendingLongitude = longitude;
    }
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingAllowsZooming
{
    return [NSSet setWithObject:@"zoomEnabled"];
}

- (BOOL)allowsZooming
{
    return self.zoomEnabled;
}

- (void)setAllowsZooming:(BOOL)allowsZooming
{
    MGLLogDebug(@"Setting allowsZooming: %@", VMGLStringFromBOOL(allowsZooming));
    self.zoomEnabled = allowsZooming;
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingAllowsScrolling
{
    return [NSSet setWithObject:@"scrollEnabled"];
}

- (BOOL)allowsScrolling
{
    return self.scrollEnabled;
}

- (void)setAllowsScrolling:(BOOL)allowsScrolling
{
    MGLLogDebug(@"Setting allowsScrolling: %@", VMGLStringFromBOOL(allowsScrolling));
    self.scrollEnabled = allowsScrolling;
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingAllowsRotating
{
    return [NSSet setWithObject:@"rotateEnabled"];
}

- (BOOL)allowsRotating
{
    return self.rotateEnabled;
}

- (void)setAllowsRotating:(BOOL)allowsRotating
{
    MGLLogDebug(@"Setting allowsRotating: %@", VMGLStringFromBOOL(allowsRotating));
    self.rotateEnabled = allowsRotating;
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingAllowsTilting
{
    return [NSSet setWithObject:@"pitchEnabled"];
}

- (BOOL)allowsTilting
{
    return self.pitchEnabled;
}

- (void)setAllowsTilting:(BOOL)allowsTilting
{
    MGLLogDebug(@"Setting allowsTilting: %@", VMGLStringFromBOOL(allowsTilting));
    self.pitchEnabled = allowsTilting;
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingShowsHeading
{
    return [NSSet setWithObject:@"showsUserHeadingIndicator"];
}

- (BOOL)showsHeading
{
    return self.showsUserHeadingIndicator;
}

- (void)setShowsHeading:(BOOL)showsHeading
{
    MGLLogDebug(@"Setting showsHeading: %@", VMGLStringFromBOOL(showsHeading));
    self.showsUserHeadingIndicator = showsHeading;
}

@end
