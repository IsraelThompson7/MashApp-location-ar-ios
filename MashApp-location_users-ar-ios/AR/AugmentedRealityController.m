//
//  AugmentedRealityController.m
//  MashApp-location_users-ar-ios
//
//  Created by Igor Khomenko on 3/26/12.
//  Copyright (c) 2012 Injoit. All rights reserved.
//

#import "AugmentedRealityController.h"
#import "ARCoordinate.h"
#import "ARGeoCoordinate.h"
#import "MarkerView.h"

#define kFilteringFactor 0.05
#define degreesToRadian(x) (M_PI * (x) / 180.0)
#define radianToDegrees(x) ((x) * 180.0/M_PI)

#define canvasFrame CGRectMake(0, 0, 320, 480)

#pragma mark -

@interface AugmentedRealityController (Private) 
- (void) updateCenterCoordinate;
- (void) startListening;
- (double) findDeltaOfRadianCenter:(double*)centerAzimuth coordinateAzimuth:(double)pointAzimuth betweenNorth:(BOOL*) isBetweenNorth;
- (CGPoint) pointInView:(UIView *)realityView withView:(UIView *)viewToDraw forCoordinate:(ARCoordinate *)coordinate;
- (BOOL) viewportContainsView:(UIView *)viewToDraw forCoordinate:(ARCoordinate *)coordinate;
@end

#pragma mark -

@implementation AugmentedRealityController

@synthesize locationManager, accelerometerManager, displayView, centerCoordinate, scaleViewsBasedOnDistance, rotateViewsBasedOnPerspective, maximumScaleDistance, minimumScaleFactor, maximumRotationAngle, centerLocation, coordinates, currentOrientation, degreeRange, rootViewController;
@synthesize latestHeading, viewAngle, coordinateViews;
@synthesize captureSession;


#pragma mark - 
#pragma mark Init & dealloc 

- (id)initWithViewController:(UIViewController *)vc {
	coordinates		= [[NSMutableArray alloc] init];
	coordinateViews	= [[NSMutableArray alloc] init];
	latestHeading	= -1.0f;

	// save root controller
	self.rootViewController = vc; 

	self.maximumScaleDistance = 1.3;
	self.minimumScaleFactor = 0.3;
	self.scaleViewsBasedOnDistance = YES;
	self.rotateViewsBasedOnPerspective = NO;
	self.maximumRotationAngle = M_PI / 6.0;

	// add work view
	displayView = [[UIImageView alloc] initWithFrame:canvasFrame]; 
    [vc.view addSubview:displayView];
    displayView.clipsToBounds = YES;
    
	self.currentOrientation = UIDeviceOrientationPortrait; 
	self.degreeRange = self.displayView.bounds.size.width / 12; 

	[self startListening];
    	
    return self;
}

- (void)dealloc {

	self.locationManager = nil;
	self.coordinateViews = nil;

	[coordinates release];
    [super dealloc];
}

// This is needed to start showing the Camera of the Augemented Reality Toolkit.
- (void)displayAR{
    [self initCapture];
}

- (void)dissmisAR {
    [captureSession stopRunning];
    
    [displayView setImage:nil];
    for(UIView *view in displayView.subviews){
        [view removeFromSuperview];
    }
    
    self.captureSession = nil;
}

- (void)startListening {
	
	// start our heading readings and our accelerometer readings.
	if (!self.locationManager) {
		locationManager = [[CLLocationManager alloc] init];
		self.locationManager.headingFilter = kCLHeadingFilterNone;
		self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
		[self.locationManager startUpdatingHeading];
		[self.locationManager startUpdatingLocation];
		self.locationManager.delegate = self;
	}
			
	if (!self.accelerometerManager) {
		self.accelerometerManager = [UIAccelerometer sharedAccelerometer];
		self.accelerometerManager.updateInterval = 0.1;
		self.accelerometerManager.delegate = self;
	}
	
	if (!self.centerCoordinate) 
		self.centerCoordinate = [ARCoordinate coordinateWithRadialDistance:1.0 inclination:0 azimuth:0];
}


#pragma mark - 
#pragma mark CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
	latestHeading = degreesToRadian(newHeading.magneticHeading);
	[self updateCenterCoordinate];
}

- (BOOL)locationManagerShouldDisplayHeadingCalibration:(CLLocationManager *)manager {
	return YES;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
	// set new own location
    if (oldLocation == nil){
		self.centerLocation = newLocation;
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
	
}


#pragma mark - 
#pragma mark UIAccelerometerDelegate 

- (void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration {
	
	switch (currentOrientation) {
		case UIDeviceOrientationLandscapeLeft:
			viewAngle = atan2(acceleration.x, acceleration.z);
			break;
		case UIDeviceOrientationLandscapeRight:
			viewAngle = atan2(-acceleration.x, acceleration.z);
			break;
		case UIDeviceOrientationPortrait:
			viewAngle = atan2(acceleration.y, acceleration.z);
			break;
		case UIDeviceOrientationPortraitUpsideDown:
			viewAngle = atan2(-acceleration.y, acceleration.z);
			break;	
		default:
			break;
	}
	
	[self updateCenterCoordinate];
}


#pragma mark - 
#pragma mark  Private methods 

// called when updating acceleration or locationHeading 
- (void)updateCenterCoordinate {
	double adjustment = 0;
	
	if (currentOrientation == UIDeviceOrientationLandscapeLeft)
		adjustment = degreesToRadian(270); 
	else if (currentOrientation == UIDeviceOrientationLandscapeRight)
		adjustment = degreesToRadian(90);
	else if (currentOrientation == UIDeviceOrientationPortraitUpsideDown)
		adjustment = degreesToRadian(180);
    
	self.centerCoordinate.azimuth = latestHeading - adjustment;
	[self updateLocations];
}

// called by the two next methods 
- (double)findDeltaOfRadianCenter:(double*)centerAzimuth coordinateAzimuth:(double)pointAzimuth betweenNorth:(BOOL*)isBetweenNorth {
    
	if (*centerAzimuth < 0.0) 
		*centerAzimuth = (M_PI * 2.0) + *centerAzimuth;
	
	if (*centerAzimuth > (M_PI * 2.0)) 
		*centerAzimuth = *centerAzimuth - (M_PI * 2.0);
	
	double deltaAzimuth = ABS(pointAzimuth - *centerAzimuth);
	*isBetweenNorth		= NO;
    
	// If values are on either side of the Azimuth of North we need to adjust it.  Only check the degree range
	if (*centerAzimuth < degreesToRadian(self.degreeRange) && pointAzimuth > degreesToRadian(360-self.degreeRange)) {
		deltaAzimuth	= (*centerAzimuth + ((M_PI * 2.0) - pointAzimuth));
		*isBetweenNorth = YES;
	}
	else if (pointAzimuth < degreesToRadian(self.degreeRange) && *centerAzimuth > degreesToRadian(360-self.degreeRange)) {
		deltaAzimuth	= (pointAzimuth + ((M_PI * 2.0) - *centerAzimuth));
		*isBetweenNorth = YES;
	}
    
	return deltaAzimuth;
}

// called by updateLocations 
- (CGPoint)pointInView:(UIView *)realityView withView:(UIView *)viewToDraw forCoordinate:(ARCoordinate *)coordinate {	
	
	CGPoint point;
	CGRect realityBounds	= realityView.bounds;
	double currentAzimuth	= self.centerCoordinate.azimuth;
	double pointAzimuth		= coordinate.azimuth;
	BOOL isBetweenNorth		= NO;
	double deltaAzimuth		= [self findDeltaOfRadianCenter: &currentAzimuth coordinateAzimuth:pointAzimuth betweenNorth:&isBetweenNorth];
	
	if ((pointAzimuth > currentAzimuth && !isBetweenNorth) || (currentAzimuth > degreesToRadian(360-self.degreeRange) && pointAzimuth < degreesToRadian(self.degreeRange)))
		point.x = (realityBounds.size.width / 2) + ((deltaAzimuth / degreesToRadian(1)) * 12);  // Right side of Azimuth
	else
		point.x = (realityBounds.size.width / 2) - ((deltaAzimuth / degreesToRadian(1)) * 12);	// Left side of Azimuth
	
	point.y = (realityBounds.size.height / 2) + (radianToDegrees(M_PI_2 + viewAngle)  * 2.0);
	
	return point;
}

// called by updateLocations 
- (BOOL)viewportContainsView:(UIView *)viewToDraw  forCoordinate:(ARCoordinate *)coordinate {    
	double currentAzimuth = self.centerCoordinate.azimuth;
	double pointAzimuth	  = coordinate.azimuth;
	BOOL isBetweenNorth	  = NO;
	double deltaAzimuth	  = [self findDeltaOfRadianCenter: &currentAzimuth coordinateAzimuth:pointAzimuth betweenNorth:&isBetweenNorth];
	BOOL result			  = NO;
	
	if (deltaAzimuth <= degreesToRadian(self.degreeRange))
		result = YES;
    
	return result;
}


#pragma mark - 
#pragma mark Properties

- (void)setCenterLocation:(CLLocation *)newLocation {
	[centerLocation release];
	centerLocation = [newLocation retain];
	
    int index			= 0;
	for (ARGeoCoordinate *geoLocation in self.coordinates) {
		
		if ([geoLocation isKindOfClass:[ARGeoCoordinate class]]) {
			[geoLocation calibrateUsingOrigin:centerLocation];
			
			if (geoLocation.radialDistance > self.maximumScaleDistance) {
				self.maximumScaleDistance = geoLocation.radialDistance;
            }
		}
        
        // update distance
        MarkerView *marker = [coordinateViews objectAtIndex:index];
        [marker updateDistance:centerLocation];
        
        ++index;
	}
}


#pragma mark -
#pragma mark Public methods 

- (void)addCoordinate:(ARCoordinate *)coordinate augmentedView:(UIView *)agView animated:(BOOL)animated {
	
	[coordinates addObject:coordinate];
	
	if (coordinate.radialDistance > self.maximumScaleDistance) 
		self.maximumScaleDistance = coordinate.radialDistance;
	
	[coordinateViews addObject:agView];
}

- (void)removeCoordinate:(ARCoordinate *)coordinate {
	[self removeCoordinate:coordinate animated:YES];
}

- (void)removeCoordinate:(ARCoordinate *)coordinate animated:(BOOL)animated {
	[coordinates removeObject:coordinate];
}

- (void)removeCoordinates:(NSArray *)coordinateArray {	
	
	for (ARCoordinate *coordinateToRemove in coordinateArray) {
		NSUInteger indexToRemove = [coordinates indexOfObject:coordinateToRemove];
		
		//TODO: Error checking in here.
		[coordinates	 removeObjectAtIndex:indexToRemove];
		[coordinateViews removeObjectAtIndex:indexToRemove];
	}
}

- (void)updateLocations {
	
	if (!coordinateViews || [coordinateViews count] == 0) {
		return;
    }
	
	int index			= 0;
	int totalDisplayed	= 0;
	
	for (ARCoordinate *item in coordinates) {
		
		UIView *viewToDraw = [coordinateViews objectAtIndex:index];
		
		if ([self viewportContainsView:viewToDraw forCoordinate:item]) {
			
			CGPoint loc = [self pointInView:self.displayView withView:viewToDraw forCoordinate:item];
            
			CGFloat scaleFactor = 1.0;
	
			if ([self scaleViewsBasedOnDistance]) 
				scaleFactor = 1.0 - self.minimumScaleFactor * (item.radialDistance / self.maximumScaleDistance);
			
			float width	 = viewToDraw.bounds.size.width  * scaleFactor;
			float height = viewToDraw.bounds.size.height * scaleFactor;
			
			viewToDraw.frame = CGRectMake(loc.x - width / 2.0, loc.y - (height / 2.0), width, height);

			totalDisplayed++;
			
			CATransform3D transform = CATransform3DIdentity;
			
			// Set the scale if it needs it. Scale the perspective transform if we have one.
			if ([self scaleViewsBasedOnDistance]) 
				transform = CATransform3DScale(transform, scaleFactor, scaleFactor, scaleFactor);
			
			if ([self rotateViewsBasedOnPerspective]) {
				transform.m34 = 1.0 / 300.0;
				
				double itemAzimuth		= item.azimuth;
				double centerAzimuth	= self.centerCoordinate.azimuth;
				
				if (itemAzimuth - centerAzimuth > M_PI) 
					centerAzimuth += 2 * M_PI;
				
				if (itemAzimuth - centerAzimuth < -M_PI) 
					itemAzimuth  += 2 * M_PI;
				
				double angleDifference	= itemAzimuth - centerAzimuth;
				transform				= CATransform3DRotate(transform, self.maximumRotationAngle * angleDifference / 0.3696f , 0, 1, 0);
			}
			
			viewToDraw.layer.transform = transform;
			
			//if we don't have a superview, set it up.
			if (!([viewToDraw superview])) {
				[self.displayView addSubview:viewToDraw];
				[self.displayView sendSubviewToBack:viewToDraw];
			}
            
           
            
            if(viewToDraw.frame.origin.y < 0 || viewToDraw.frame.size.height > displayView.frame.size.height){
                 NSLog(@"y=%f, h=%f", viewToDraw.frame.origin.y, viewToDraw.frame.size.height);
               // [viewToDraw removeFromSuperview];
            }
		
        } else{ 
			[viewToDraw removeFromSuperview];
        }
		
		index++;
	}
}


#pragma mark -
#pragma mark Capture

- (IBAction) initCapture {
    
	/*We setup the input*/
	AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput 
										  deviceInputWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] 
										  error:nil];
	/*We setupt the output*/
	AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
	/*While a frame is processes in -captureOutput:didOutputSampleBuffer:fromConnection: delegate methods no other frames are added in the queue.
	 If you don't want this behaviour set the property to NO */
	captureOutput.alwaysDiscardsLateVideoFrames = YES; 
	/*We specify a minimum duration for each frame (play with this settings to avoid having too many frames waiting
	 in the queue because it can cause memory issues). It is similar to the inverse of the maximum framerate.
	 In this example we set a min frame duration of 1/10 seconds so a maximum framerate of 10fps. We say that
	 we are not able to process more than 10 frames per second.*/
	captureOutput.minFrameDuration = CMTimeMake(1, 15);
	
	/*We create a serial queue to handle the processing of our frames*/
	dispatch_queue_t queue;
	queue = dispatch_queue_create("cameraQueue", NULL);
	[captureOutput setSampleBufferDelegate:self queue:queue];
	dispatch_release(queue);
	// Set the video output to store frame in BGRA (It is supposed to be faster)
	NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey; 
	NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA]; 
	NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key]; 
	[captureOutput setVideoSettings:videoSettings]; 
	/*And we create a capture session*/
	captureSession = [[AVCaptureSession alloc] init];
	/*We add input and output*/
	[self.captureSession addInput:captureInput];
	[self.captureSession addOutput:captureOutput];
    
    [captureOutput release];
    
    [self.captureSession setSessionPreset:AVCaptureSessionPreset640x480];
	
	/*We start the capture*/
	[self.captureSession startRunning];
}

#pragma mark -
#pragma mark AVCaptureSession delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
	   fromConnection:(AVCaptureConnection *)connection 
{ 
	/*We create an autorelease pool because as we are not in the main_queue our code is
	 not executed in the main thread. So we have to create an autorelease pool for the thread we are in*/
	
    //	CGFloat angleInRadians = -90 * (M_PI / 180);
	
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer); 
    /*Lock the image buffer*/
    CVPixelBufferLockBaseAddress(imageBuffer,0); 
    /*Get information about the image*/
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer); 
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer); 
    size_t width = CVPixelBufferGetWidth(imageBuffer); 
    size_t height = CVPixelBufferGetHeight(imageBuffer);  
    
    /*Create a CGImageRef from the CVImageBufferRef*/
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); 
    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    //	CGContextRotateCTM(newContext, -angleInRadians);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext); 
	
    /*We release some components*/
    CGContextRelease(newContext); 
    CGColorSpaceRelease(colorSpace);
    
    /*We display the result on the custom layer. All the display stuff must be done in the main thread because
	 UIKit is no thread safe, and as we are not in the main thread (remember we didn't use the main_queue)
	 we use performSelectorOnMainThread to call our CALayer and tell it to display the CGImage.*/
	//[self.customLayer performSelectorOnMainThread:@selector(setContents:) withObject: (id) newImage waitUntilDone:YES];
	
    
	/*We display the result on the image view (We need to change the orientation of the image so that the video is displayed correctly).
	 Same thing as for the CALayer we are not in the main thread so ...*/
	UIImage *image= [UIImage imageWithCGImage:newImage scale:1 orientation:UIImageOrientationRight];
	
    //    + (UIImage *)imageWithCGImage:(CGImageRef)imageRef scale:(CGFloat)scale orientation:(UIImageOrientation)orientation
    
    
	/*We relase the CGImageRef*/
	CGImageRelease(newImage);
	
	[displayView performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:YES];
	
	/*We unlock the  image buffer*/
	CVPixelBufferUnlockBaseAddress(imageBuffer,0);
	
	[pool drain];
} 

@end
