//
//  ViewController.h
//  MashApp-location_users-ar-ios
//
//  Created by Igor Khomenko on 3/26/12.
//  Copyright (c) 2012 Injoit. All rights reserved.
//

#import "ARKit.h"
#import "MarkerView.h"
#import "ARCoordinate.h"
#import "ARGeoCoordinate.h"
#import "AugmentedRealityController.h"

@interface ViewController : UIViewController <ActionStatusDelegate, ARLocationDataSource>

@property (nonatomic, retain) NSArray *points;
@property (nonatomic, retain) AugmentedRealityController *arController;

- (void) setupAR;

@end
