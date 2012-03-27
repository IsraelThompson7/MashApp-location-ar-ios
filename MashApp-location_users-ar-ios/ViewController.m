//
//  ViewController.m
//  MashApp-location_users-ar-ios
//
//  Created by Igor Khomenko on 3/26/12.
//  Copyright (c) 2012 Injoit. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

@synthesize points;
@synthesize arController;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // check AR support
    if([ARKit deviceSupportsAR]){
        
        // auth app
        [QBAuthService authorizeAppId:appID key:authKey secret:authSecret delegate:self];
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	
    }else{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Alert" message:@"Augmented Reality is not supported on this device" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
        [alert release];
	}
}

- (void) dealloc{
    [points release];
    [arController release];
    
    [super dealloc];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

- (void) setupAR{
    // setup AR
    arController = [[AugmentedRealityController alloc] initWithViewController:self];
	arController.debugMode = YES;
	arController.scaleViewsBasedOnDistance = NO;
	arController.minimumScaleFactor = 0.5;
	arController.rotateViewsBasedOnPerspective = NO;
    
    // add markers
    if([[self points] count] > 0){
        for(QBLGeoData *userLocation in [self points]){
            // add marker
            UIView *markerView = [self viewForLocationPoint:userLocation];
            CLLocation *location = [[CLLocation alloc] initWithLatitude:userLocation.longitude longitude:userLocation.longitude];
            ARCoordinate *coordinateForUser = [ARGeoCoordinate coordinateWithLocation:location locationTitle:userLocation.user.fullName];
            [location release];
            [arController addCoordinate:coordinateForUser augmentedView:markerView animated:NO];
        }
    }
    
    // show
    [arController displayAR];
}


#pragma mark -
#pragma mark ARLocationDataSource

- (UIView *)viewForLocationPoint:(QBLGeoData *)location{
    MarkerView *market = [[[MarkerView alloc] initWithGeoPoint:location] autorelease];
    return market;
}

-(NSArray *)points {    
    return points;
}


#pragma mark -
#pragma mark ActionStatusDelegate

- (void)completedWithResult:(Result *)result{
    
    if([result isKindOfClass:[QBAAuthSessionCreationResult class]]){
        if(result.success){
            //get points
            QBLGeoDataSearchRequest *searchRequest = [[QBLGeoDataSearchRequest alloc] init];
            searchRequest.last_only = YES; // Only last location
            searchRequest.perPage = 15; // Pins limit for each page
            [QBLocationService findGeoData:searchRequest delegate:self];
            [searchRequest release];
        }else{
            NSLog(@"errors=%@", result.errors);
        }
    }else 	if([result isKindOfClass:[QBLGeoDataPagedResult class]]){
        if (result.success){
            
            // save points
            QBLGeoDataPagedResult *geoDataSearchRes = (QBLGeoDataPagedResult *)result;
            self.points = geoDataSearchRes.geodatas;
            
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
            
            
            // setup AR
            [self setupAR];
        }else{
            NSLog(@"errors=%@", result.errors);
        }
    }
}

@end
