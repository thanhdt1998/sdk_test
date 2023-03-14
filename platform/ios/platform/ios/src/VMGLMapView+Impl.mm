#import "VMGLMapView+Impl.h"
#import "VMGLMapView+OpenGL.h"
#import "VMGLStyle_Private.h"
#import "NSBundle+MGLAdditions.h"

std::unique_ptr<VMGLMapViewImpl> VMGLMapViewImpl::Create(VMGLMapView* nativeView) {
    return std::make_unique<MGLMapViewOpenGLImpl>(nativeView);
}

VMGLMapViewImpl::VMGLMapViewImpl(VMGLMapView* nativeView_) : mapView(nativeView_) {
}

void VMGLMapViewImpl::render() {
    [mapView renderSync];
}

void VMGLMapViewImpl::onCameraWillChange(mbgl::MapObserver::CameraChangeMode mode) {
    bool animated = mode == mbgl::MapObserver::CameraChangeMode::Animated;
    [mapView cameraWillChangeAnimated:animated];
}

void VMGLMapViewImpl::onCameraIsChanging() {
    [mapView cameraIsChanging];
}

void VMGLMapViewImpl::onCameraDidChange(mbgl::MapObserver::CameraChangeMode mode) {
    bool animated = mode == mbgl::MapObserver::CameraChangeMode::Animated;
    [mapView cameraDidChangeAnimated:animated];
}

void VMGLMapViewImpl::onWillStartLoadingMap() {
    [mapView mapViewWillStartLoadingMap];
}

void VMGLMapViewImpl::onDidFinishLoadingMap() {
    [mapView mapViewDidFinishLoadingMap];
}

void VMGLMapViewImpl::onDidFailLoadingMap(mbgl::MapLoadError mapError, const std::string& what) {
    NSString *description;
    MGLErrorCode code;
    switch (mapError) {
        case mbgl::MapLoadError::StyleParseError:
            code = MGLErrorCodeParseStyleFailed;
            description = NSLocalizedStringWithDefaultValue(@"PARSE_STYLE_FAILED_DESC", nil, nil, @"The map failed to load because the style is corrupted.", @"User-friendly error description");
            break;
        case mbgl::MapLoadError::StyleLoadError:
            code = MGLErrorCodeLoadStyleFailed;
            description = NSLocalizedStringWithDefaultValue(@"LOAD_STYLE_FAILED_DESC", nil, nil, @"The map failed to load because the style can’t be loaded.", @"User-friendly error description");
            break;
        case mbgl::MapLoadError::NotFoundError:
            code = MGLErrorCodeNotFound;
            description = NSLocalizedStringWithDefaultValue(@"STYLE_NOT_FOUND_DESC", nil, nil, @"The map failed to load because the style can’t be found or is incompatible.", @"User-friendly error description");
            break;
        default:
            code = MGLErrorCodeUnknown;
            description = NSLocalizedStringWithDefaultValue(@"LOAD_MAP_FAILED_DESC", nil, nil, @"The map failed to load because an unknown error occurred.", @"User-friendly error description");
    }
    NSDictionary *userInfo = @{
        NSLocalizedDescriptionKey: description,
        NSLocalizedFailureReasonErrorKey: @(what.c_str()),
    };
    NSError *error = [NSError errorWithDomain:MGLErrorDomain code:code userInfo:userInfo];

    [mapView mapViewDidFailLoadingMapWithError:error];
}

void VMGLMapViewImpl::onWillStartRenderingFrame() {
    [mapView mapViewWillStartRenderingFrame];
}

void VMGLMapViewImpl::onDidFinishRenderingFrame(mbgl::MapObserver::RenderFrameStatus status) {
    bool fullyRendered = status.mode == mbgl::MapObserver::RenderMode::Full;
    [mapView mapViewDidFinishRenderingFrameFullyRendered:fullyRendered];
}

void VMGLMapViewImpl::onWillStartRenderingMap() {
    [mapView mapViewWillStartRenderingMap];
}

void VMGLMapViewImpl::onDidFinishRenderingMap(mbgl::MapObserver::RenderMode mode) {
    bool fullyRendered = mode == mbgl::MapObserver::RenderMode::Full;
    [mapView mapViewDidFinishRenderingMapFullyRendered:fullyRendered];
}

void VMGLMapViewImpl::onDidFinishLoadingStyle() {
    [mapView mapViewDidFinishLoadingStyle];
}

void VMGLMapViewImpl::onSourceChanged(mbgl::style::Source& source) {
    NSString *identifier = @(source.getID().c_str());
    VMGLSource * nativeSource = [mapView.style sourceWithIdentifier:identifier];
    [mapView sourceDidChange:nativeSource];
}

void VMGLMapViewImpl::onDidBecomeIdle() {
    [mapView mapViewDidBecomeIdle];
}

void VMGLMapViewImpl::onStyleImageMissing(const std::string& imageIdentifier) {
    NSString *imageName = [NSString stringWithUTF8String:imageIdentifier.c_str()];
    [mapView didFailToLoadImage:imageName];
}

bool VMGLMapViewImpl::onCanRemoveUnusedStyleImage(const std::string &imageIdentifier) {
    NSString *imageName = [NSString stringWithUTF8String:imageIdentifier.c_str()];
    return [mapView shouldRemoveStyleImage:imageName];
}
