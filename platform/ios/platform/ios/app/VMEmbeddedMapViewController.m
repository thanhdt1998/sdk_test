@import Mapbox;

#import "VMEmbeddedMapViewController.h"

typedef NS_ENUM(NSInteger, MBXEmbeddedControl) {
    VMEmbeddedControlZoom = 0,
    VMEmbeddedControlScroll,
    VMEmbeddedControlRotation,
    VMEmbeddedControlPitch
};

@interface VMEmbeddedMapViewController () <UIScrollViewDelegate>

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet VMGLMapView *mapView;

@end

@implementation VMEmbeddedMapViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.scrollView.delegate = self;
    self.scrollView.contentSize = self.view.bounds.size;
}

- (IBAction)didSwitch:(UISwitch *)controlSwitch {
    [self switchControl:controlSwitch.tag];
}

- (IBAction)rotation:(UIRotationGestureRecognizer *)rotationGesture {
    self.mapView.transform = CGAffineTransformRotate(rotationGesture.view.transform, rotationGesture.rotation);
}

- (void)switchControl:(MBXEmbeddedControl) control {
    switch (control) {
        case VMEmbeddedControlZoom:
            self.mapView.zoomEnabled = !self.mapView.zoomEnabled;
            break;
        case VMEmbeddedControlScroll:
            self.mapView.scrollEnabled = !self.mapView.scrollEnabled;
            break;
        case VMEmbeddedControlRotation:
            self.mapView.rotateEnabled = !self.mapView.rotateEnabled;
            break;
        case VMEmbeddedControlPitch:
            self.mapView.pitchEnabled = !self.mapView.pitchEnabled;
            break;
    }
}

- (BOOL)statusForControl:(MBXEmbeddedControl) control {
    switch (control) {
        case VMEmbeddedControlZoom:
            return self.mapView.zoomEnabled;
        case VMEmbeddedControlScroll:
            return self.mapView.scrollEnabled;
        case VMEmbeddedControlRotation:
            return self.mapView.rotateEnabled;
        case VMEmbeddedControlPitch:
            return self.mapView.pitchEnabled;
    }
}

#pragma mark UIScrollViewDelegate methods

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.mapView;
}

#pragma mark Class method

+ (NSString *)titleForControl:(MBXEmbeddedControl) control {
    switch (control) {
        case VMEmbeddedControlZoom:
            return @"Zoom Enabled";
        case VMEmbeddedControlScroll:
            return @"Scroll Enabled";
            break;
        case VMEmbeddedControlRotation:
            return @"Rotation Enabled";
            break;
        case VMEmbeddedControlPitch:
            return @"Pitch Enabled";
            break;
    }
}

@end
