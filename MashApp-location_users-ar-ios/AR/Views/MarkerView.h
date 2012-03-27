//
//  MarkerView.h
//  MashApp-location_users-ar-ios
//
//  Created by Igor Khomenko on 3/26/12.
//  Copyright (c) 2012 Injoit. All rights reserved.
//

@interface MarkerView : UIView{
    @protected
    QBLGeoData *userPoint;
    UILabel *distanceLabel;
}
@property (assign, nonatomic) id target;
@property SEL action;

- (id)initWithGeoPoint:(QBLGeoData *)_userPoint;
- (void) updateDistance:(CLLocation *)newOriginLocation;

@end