/****************************************************************************
 Copyright (c) 2013 cocos2d-x.org
 
 http://www.cocos2d-x.org
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 ****************************************************************************/

#import "IOSIAP.h"
#import "RMStore.h"
#import "RMAppReceipt.h"
#import "RMStoreAppReceiptVerifier.h"
#import "RMStoreTransactionReceiptVerifier.h"

#import "RMStoreUserDefaultsPersistence.h"

#import "CheckSubscription.h"

#define OUTPUT_LOG(...)     if (self.debug) NSLog(__VA_ARGS__);

@implementation IOSIAP {
    id<RMStoreReceiptVerifier> _receiptVerifier;
}
@synthesize debug;
-(id) init {
    if (self = [super init]){
        const BOOL iOS7OrHigher = floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1;
        _receiptVerifier = iOS7OrHigher ? [[RMStoreAppReceiptVerifier alloc] init] : [[RMStoreTransactionReceiptVerifier alloc] init];
        [RMStore defaultStore].receiptVerifier = _receiptVerifier;
        
        // For devices with os version before 7.0 to verify subscription.
         RMStoreUserDefaultsPersistence* persistence = [[RMStoreUserDefaultsPersistence alloc] init];
        [RMStore defaultStore].transactionPersistor = persistence;
    }
    return self;
}
-(void) configDeveloperInfo: (NSMutableDictionary*) cpInfo{}
-(void) payForProduct: (NSMutableDictionary*) cpInfo{
    NSString* productID = [cpInfo objectForKey:@"IAPId"];
    
    if (productID){
        [[RMStore defaultStore] requestProducts:[NSSet setWithObjects:productID, nil] success:^(NSArray *products, NSArray *invalidProductIdentifiers) {
            [[RMStore defaultStore]addPayment:productID success:^(SKPaymentTransaction *transaction) {
                [IAPWrapper onPayResult:self withRet:PaymentTransactionStatePurchased withMsg:transaction.payment.productIdentifier];
            } failure:^(SKPaymentTransaction *transaction, NSError *error) {
                [IAPWrapper onPayResult:self withRet:PaymentTransactionStateFailed withMsg:@""];
            }];
        } failure:^(NSError *error) {
            [IAPWrapper onPayResult:self withRet:PaymentTransactionStateFailed withMsg:@""];
        }];
    } else {
        [IAPWrapper onPayResult:self withRet:PaymentTransactionStateFailed withMsg:@""];
    }

}
-(void) requestProducts:(NSMutableArray *)productInfo{
    NSSet* productIDSet = [NSSet setWithArray:productInfo];
    [[RMStore defaultStore] requestProducts:productIDSet success:^(NSArray *products, NSArray *invalidProductIdentifiers) {
        [IAPWrapper onRequestProduct:self withRet:RequestSuccees withProducts:products];
    } failure:^(NSError *error) {
        [IAPWrapper onRequestProduct:self withRet:RequestFail withProducts:nil];
    }];
    
}
-(void) purchaseSubscription:(NSMutableDictionary *)subInfo {
    NSString* productID = [subInfo objectForKey:@"IAPId"];
    if (productID){
        [[RMStore defaultStore] requestProducts:[NSSet setWithObjects:productID, nil] success:^(NSArray *products, NSArray *invalidProductIdentifiers) {
            [[RMStore defaultStore]addPayment:productID success:^(SKPaymentTransaction *transaction) {
                [IAPWrapper onCheckSubscriptionResult:self withRet:SubscriptionVerifySuccess withMsg:@""];
            } failure:^(SKPaymentTransaction *transaction, NSError *error) {
                [IAPWrapper onCheckSubscriptionResult:self withRet:SubscriptionVerifyFailed withMsg:@""];
            }];
        } failure:^(NSError *error) {
            [IAPWrapper onCheckSubscriptionResult:self withRet:SubscriptionVerifyFailed withMsg:@""];
        }];
    } else {
        [IAPWrapper onCheckSubscriptionResult:self withRet:SubscriptionVerifyFailed withMsg:@""];
    }
}

-(void) checkSubscription:(NSMutableDictionary *)subInfo {
    NSString* productID = [subInfo objectForKey:@"IAPId"];
    NSString* currentTimeStr = [subInfo objectForKey:@"CurrentTime"];
    NSDate * currentTime = [NSDate date];
    if (currentTimeStr){
        currentTime = [NSDate dateWithTimeIntervalSince1970:currentTimeStr.doubleValue];
    }
    
    if (productID){
        const BOOL iOS7OrHigher = floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1;
        if (iOS7OrHigher){
            [CheckSubscription checkWithAppReceipt:productID currentTime:currentTime success:^{
                [IAPWrapper onCheckSubscriptionResult:self withRet:SubscriptionVerifySuccess withMsg:productID];
            } fail:^{
                [IAPWrapper onCheckSubscriptionResult:self withRet:SubscriptionVerifyFailed withMsg:@""];
            }];
        } else {
            [CheckSubscription checkWithTransactionReceipt:productID currentTime:currentTime success:^{
                [IAPWrapper onCheckSubscriptionResult:self withRet:SubscriptionVerifySuccess withMsg:productID];
            } fail:^{
                [IAPWrapper onCheckSubscriptionResult:self withRet:SubscriptionVerifyFailed withMsg:@""];
            }];
        }
    } else {
        [IAPWrapper onCheckSubscriptionResult:self withRet:SubscriptionVerifyFailed withMsg:@""];
    }
}

- (void)restoreCompletedTransactions {
    [[RMStore defaultStore] restoreTransactionsOnSuccess:^(NSArray *transactionArray) {
        if (transactionArray.count > 0){
            [IAPWrapper onRestoreProduct:self withRet:ProductRestored withProducts:transactionArray];
        } else {
            [IAPWrapper onRestoreProduct:self withRet:ProductRestoreFailed withProducts:nil];
        }
    } failure:^(NSError *error) {
        [IAPWrapper onRestoreProduct:self withRet:ProductRestoreFailed withProducts:nil];
    }];
}

- (void) setDebugMode: (BOOL) _debug{
    self.debug = _debug;
}
- (NSString*) getSDKVersion{
    return @"1.0";
}

- (NSString*) getPluginVersion{
    return @"1.0";
}
@end
