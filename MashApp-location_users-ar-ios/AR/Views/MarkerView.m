//
//  MarkerView.m
//  MashApp-location_users-ar-ios
//
//  Created by Igor Khomenko on 3/26/12.
//  Copyright (c) 2012 Injoit. All rights reserved.
//

#import "MarkerView.h"

#define MARKER_WIDTH 150
#define MARKER_HEIGHT 100

@implementation MarkerView

@synthesize target;
@synthesize action;

- (id)initWithGeoPoint:(QBLGeoData *)_userPoint{
    	
	CGRect theFrame = CGRectMake(0, 0, MARKER_WIDTH, MARKER_HEIGHT);
	
	if ((self = [super initWithFrame:theFrame])) {
        [self setBackgroundColor:[UIColor clearColor]];
        
        // save user
        userPoint = _userPoint;
	
        // User name
		UILabel *titleLabel	= [[UILabel alloc] initWithFrame:CGRectZero];
		[titleLabel setBackgroundColor:[UIColor colorWithWhite:.3 alpha:.8]];
		[titleLabel setTextColor:[UIColor whiteColor]];
		[titleLabel setTextAlignment:UITextAlignmentCenter];
		[titleLabel setText:[_userPoint.user fullName]];
        if(titleLabel.text == nil || [titleLabel.text isEqualToString:@""]){
            titleLabel.text = [_userPoint.user login];
        }
		[titleLabel sizeToFit];
		[titleLabel setFrame:	CGRectMake(MARKER_WIDTH / 2.0 - [titleLabel bounds].size.width / 2.0 - 4.0, 0, 
                                           [titleLabel bounds].size.width + 8.0, [titleLabel bounds].size.height + 8.0)];
        [self addSubview:titleLabel];
        [titleLabel release];
        
        // image
		UIImageView *pointView	= [[UIImageView alloc] initWithFrame:CGRectZero];
		[pointView setImage:[UIImage imageNamed:@"marker_map.png"]];
		[pointView setFrame:CGRectMake((int)(MARKER_WIDTH / 2.0 - [pointView image].size.width / 2.0), (int)(MARKER_HEIGHT / 2.0 - [pointView image].size.height / 2.0), 
                                           [pointView image].size.width, [pointView image].size.height)];
		[self addSubview:pointView];
		[pointView release];
        
        // distance
		distanceLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, MARKER_HEIGHT-20, MARKER_WIDTH, 20)];
		[distanceLabel setBackgroundColor:[UIColor clearColor]];
		[distanceLabel setTextColor:[UIColor whiteColor]];
		[distanceLabel setTextAlignment:UITextAlignmentCenter];
        [self addSubview:distanceLabel];
        [distanceLabel release];
	}
	
    return self;
}

- (void) updateDistance:(CLLocation *)newOriginLocation{
    CLLocation *pointLocation = [[CLLocation alloc] initWithLatitude:userPoint.latitude longitude:userPoint.longitude];
    CLLocationDistance distance = [pointLocation distanceFromLocation:newOriginLocation];
    
    distanceLabel.text = [NSString stringWithFormat:@"%.000f km", distance/1000];
}

- (double)distanceFrom:(CLLocationCoordinate2D)locationA to:(CLLocationCoordinate2D)locationB{
    double R = 6368500.0; // in meters
    
    double lat1 = locationA.latitude*M_PI/180.0;
    double lon1 = locationA.longitude*M_PI/180.0;
    double lat2 = locationB.latitude*M_PI/180.0;
    double lon2 = locationB.longitude*M_PI/180.0;
    
    return acos(sin(lat1) * sin(lat2) + 
                cos(lat1) * cos(lat2) *
                cos(lon2 - lon1)) * R;
}

// touch action
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    if([target respondsToSelector:action]){
        [target performSelector:action withObject:self];
    }
}

- (void)dealloc {
    [userPoint release];
    [super dealloc];
}

@end
