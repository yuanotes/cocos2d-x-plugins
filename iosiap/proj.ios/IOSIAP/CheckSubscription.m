//
//  CheckSubscription.m
//  PluginIAP
//
//  Created by Yuan Chen on 15/11/19.
//  Copyright © 2015年 cocos2dx. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CheckSubscription.h"
#import "RMStore.h"
#import "RMAppReceipt.h"
#import "RMStoreUserDefaultsPersistence.h"

#define FAIL if(failBlock)failBlock();
#define SUCCESS if(successBlock)successBlock();

@interface NSData(rm_base64)

- (NSString *)rm_stringByBase64Encoding;

@end

@implementation NSData(rm_base64)

static const char _base64EncodingTable[64] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

- (NSString *)rm_stringByBase64Encoding
{ // From: http://stackoverflow.com/a/4727124/143378
    const unsigned char * objRawData = self.bytes;
    char * objPointer;
    char * strResult;
    
    // Get the Raw Data length and ensure we actually have data
    NSInteger intLength = self.length;
    if (intLength == 0) return nil;
    
    // Setup the String-based Result placeholder and pointer within that placeholder
    strResult = (char *)calloc((((intLength + 2) / 3) * 4) + 1, sizeof(char));
    objPointer = strResult;
    
    // Iterate through everything
    while (intLength > 2) { // keep going until we have less than 24 bits
        *objPointer++ = _base64EncodingTable[objRawData[0] >> 2];
        *objPointer++ = _base64EncodingTable[((objRawData[0] & 0x03) << 4) + (objRawData[1] >> 4)];
        *objPointer++ = _base64EncodingTable[((objRawData[1] & 0x0f) << 2) + (objRawData[2] >> 6)];
        *objPointer++ = _base64EncodingTable[objRawData[2] & 0x3f];
        
        // we just handled 3 octets (24 bits) of data
        objRawData += 3;
        intLength -= 3;
    }
    
    // now deal with the tail end of things
    if (intLength != 0) {
        *objPointer++ = _base64EncodingTable[objRawData[0] >> 2];
        if (intLength > 1) {
            *objPointer++ = _base64EncodingTable[((objRawData[0] & 0x03) << 4) + (objRawData[1] >> 4)];
            *objPointer++ = _base64EncodingTable[(objRawData[1] & 0x0f) << 2];
            *objPointer++ = '=';
        } else {
            *objPointer++ = _base64EncodingTable[(objRawData[0] & 0x03) << 4];
            *objPointer++ = '=';
            *objPointer++ = '=';
        }
    }
    
    // Terminate the string-based result
    *objPointer = '\0';
    
    // Create result NSString object
    NSString *base64String = @(strResult);
    
    // Free memory
    free(strResult);
    
    return base64String;
}

@end



@implementation CheckSubscription

+(void) checkWithAppReceipt:(NSString*) productID
                currentTime:(NSDate*) currentTime
                    success:(void (^)())successBlock
                       fail:(void (^)())failBlock
{
    RMAppReceipt* receipt = [RMAppReceipt bundleReceipt];
    // Get receipt
    if (receipt){
        if ([receipt containsActiveAutoRenewableSubscriptionOfProductIdentifier:productID forDate:currentTime]){
            SUCCESS
        } else {
            FAIL
        }
    } else {
        FAIL
    }
}

+(void)checkWithTransactionReceipt:(NSString*) productID
                        currentTime:(NSDate*) currentTime
                            success:(void (^)())successBlock
                               fail:(void (^)())failBlock {
    
    RMStoreUserDefaultsPersistence * persistor =  [[RMStore defaultStore] transactionPersistor];
    NSArray* transactions = [persistor transactionsForProductOfIdentifier:productID];
    for (SKPaymentTransaction*  transaction in transactions) {
        [CheckSubscription verifyTransaction:transaction productID:productID currentTime:currentTime  success:^{
            SUCCESS
        } failure:^(NSError *error) {
            FAIL
        }];
    }
}




+ (void)verifyTransaction:(SKPaymentTransaction*)transaction
                productID:(NSString*)productID
              currentTime:(NSDate*)currentTime
                  success:(void (^)())successBlock
                  failure:(void (^)())failBlock
{
    NSString *receipt = [transaction.transactionReceipt rm_stringByBase64Encoding];
    if (receipt == nil)
    {
        FAIL
        return;
    }
    static NSString *receiptDataKey = @"receipt-data";
    NSDictionary *jsonReceipt = @{receiptDataKey : receipt};
    
    NSError *error;
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:jsonReceipt options:0 error:&error];
    if (!requestData)
    {
        FAIL
        return;
    }
    
    static NSString *productionURL = @"https://buy.itunes.apple.com/verifyReceipt";
    
    [self verifyRequestData:requestData productID:productID currentTime:currentTime url:productionURL success:successBlock failure:failBlock];
}

+ (void)verifyRequestData:(NSData*)requestData
                productID:(NSString*)productID
              currentTime:(NSDate*)currentTime
                      url:(NSString*)urlString
                  success:(void (^)())successBlock
                  failure:(void (^)())failBlock
{
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPBody = requestData;
    static NSString *requestMethod = @"POST";
    request.HTTPMethod = requestMethod;
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!data)
            {
                FAIL
                return;
            }
            NSError *jsonError;
            NSDictionary *responseJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (!responseJSON)
            {
                FAIL
            }
            
            static NSString *statusKey = @"status";
            NSInteger statusCode = [responseJSON[statusKey] integerValue];
            
            static NSInteger successCode = 0;
            static NSInteger sandboxCode = 21007;
            if (statusCode == successCode)
            {
                NSDictionary* jsonReceipt = [responseJSON objectForKey:@"receipt"];
                if (jsonReceipt == nil){
                    FAIL
                    return;
                }
                NSArray* jsonInApp = [jsonReceipt objectForKey:@"in_app"];
                
                if (jsonInApp == nil){
                    FAIL
                    return;
                }
                
                BOOL found = false;
                for (id prod in jsonInApp) {
                    NSDictionary* product = prod;
                    NSString* proIDinJson = [product objectForKey:@"product_id"];
                    if ([proIDinJson isEqual:productID]) {
                        NSDateFormatter * formatter = [NSDateFormatter new];
                        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss VV";
                        //NSDate * purchaseDate = [formatter dateFromString:product[@"purchase_date"]];
                        NSDate * expirationDate = [formatter dateFromString:product[@"expires_date"]];
                        if ([currentTime compare:expirationDate] != NSOrderedDescending){
                            found = true;
                            SUCCESS
                            break;
                        }
                    }
                }
                if (!found){
                    FAIL
                }
            }
            else if (statusCode == sandboxCode)
            {
                // From: https://developer.apple.com/library/ios/#technotes/tn2259/_index.html
                // See also: http://stackoverflow.com/questions/9677193/ios-storekit-can-i-detect-when-im-in-the-sandbox
                // Always verify your receipt first with the production URL; proceed to verify with the sandbox URL if you receive a 21007 status code. Following this approach ensures that you do not have to switch between URLs while your application is being tested or reviewed in the sandbox or is live in the App Store.
                static NSString *sandboxURL = @"https://sandbox.itunes.apple.com/verifyReceipt";
                [self verifyRequestData:requestData productID:productID currentTime:currentTime url:sandboxURL success:successBlock failure:failBlock];
            }
            else
            {
                FAIL
            }
        });
    });
}

@end