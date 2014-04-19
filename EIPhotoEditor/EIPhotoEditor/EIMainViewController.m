//
//  EIMainViewController.m
//  EIPhotoEditor
//
//  Created by Anwu Yang on 14-3-26.
//  Copyright (c) 2014年 Everimaging. All rights reserved.
//

#import <AssetsLibrary/AssetsLibrary.h>
#import "MyButton.h"
#import "EIMainViewController.h"
#import "EIPhotoSDK.h"

#if ! __has_feature(objc_arc)
#error this file is ARC only. Either turn on ARC for the project or use -fobjc-arc flag
#endif

static CGFloat const kBottombarHeight = 60.0f;

@interface EIMainViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIPopoverControllerDelegate, EIPhotoSDKEditorControllerDelegate>

@end

@implementation EIMainViewController
{
    @private
    UIImageView *_imageView;    // Used for displaying image
    UIPopoverController *_popover; // Used for holding image picker in iPad
    UIImageView* _noPhotoView;
    UIActivityIndicatorView* _saveImageActivityIndicator;
    NSMutableArray *_editorSessions;    //Save editor sessions
    BOOL _isImagePickerShowed;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem = nil;
    self.title = NSLocalizedString(@"Photo Editor", nil);
    self.view.backgroundColor = [UIColor colorWithRed:35.f/255.f green:39.f/255.f blue:48.f/255.f alpha:1.0];
    
    /*
    // register kEIPhotoEditorSessionCancelledNotification notificaton (posted when session (edier controller) closed)
    [[NSNotificationCenter defaultCenter] addObserverForName:kEIPhotoEditorSessionCancelledNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
    }];
     */
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (nil == _imageView) {
        [self setupView];
    }
}

- (void)didClickButtonPicker:(UIButton *)sender
{
    _isImagePickerShowed = YES;
    //Use UIImagePickerController to pick up an image
    UIImagePickerController * imagePicker = [[UIImagePickerController alloc] init];
    [imagePicker setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
    [imagePicker setDelegate:self];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self presentViewController:imagePicker animated:YES completion:nil];
    }else {
        CGRect sourceRect = [sender convertRect:sender.frame toView:self.view];
        [self presentViewControllerInPopover:imagePicker fromRect:sourceRect];
    }
}

- (void)didClickButtonEditor
{
    if (_isImagePickerShowed) {
        return;
    }
    //Use EIPhotoSDKEditorController to edit an image
    UIImage *sampleImage = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"sample.jpg" ofType:nil]];
    [self launchPhotoEditorWithImage:sampleImage highResolutionImage:nil];
    _noPhotoView.hidden = YES;
}

- (void)setPhotoEditorCustomizationOptions
{
    /*
    // set status bar hidden here, when editor opened
    [EIPhotoEditorCustomization setStatusBarHidden:NO];
     */
    
    /*
    // set status bar style when status bar not hide, only available for iOS7 and later
    [EIPhotoEditorCustomization setStatusBarStyle:UIStatusBarStyleLightContent];
     */

    /*
    // set supported orientation on ipad, default is UIInterfaceOrientationMaskAll
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [EIPhotoEditorCustomization setSupportedIpadOrientationMask:UIInterfaceOrientationMaskLandscape];
    }
     */
    
    // set editor toolbar supported module, you can specify all the moduls in EIPhotoEditorCustomization in any order, or skip any of them
    [EIPhotoEditorCustomization setToolOrder:@[kEIEnhance, kEIScene, kEIBaseAdjust, kEIAdvanceAdjust, kEIEffect, kEIRotate, kEICrop, kEIFrame, kEISticker, kEIText, kEITiltshift]];
}

- (void)launchPhotoEditorWithImage:(UIImage *)editingResImage highResolutionImage:(UIImage *)highResImage
{
    // Customize the editor's apperance. The customization options really only need to be set once in this case since they are never changing, so we used dispatch once here.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self setPhotoEditorCustomizationOptions];
    });
    
    [_editorSessions removeAllObjects];
    
    NSError *error = nil;
    EIPhotoSDKEditorController *ctrler = [EIPhotoSDK photoEditorControllerWithImage:editingResImage error:&error];
    if (nil == ctrler) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil) message:error.localizedDescription delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil] show];
        return;
    }
    
    ctrler.editorDelegate = self;
    
    // If a high res image is passed, create the high res context with the image and the photo editor.
    if (nil != highResImage) {
        [self setupHighResContextForPhotoEditor:ctrler withImage:highResImage];
    }
    
    // Present the photo editor.
    [self presentViewController:ctrler animated:YES completion:nil];
}

- (void)setupHighResContextForPhotoEditor:(EIPhotoSDKEditorController *)photoEditor withImage:(UIImage *)highResImage
{
    // Capture a reference to the editor's session, which internally tracks user actions on a photo.
    EIPhotoSDKSession *session = [photoEditor session];
    [_editorSessions addObject:session];
    
    EIPhotoSDKContext *context = [session createContextWithImage:highResImage maxPixelSize:MAXFLOAT];
    [context renderWithBegin:^{
        self.view.userInteractionEnabled = NO;
        
        _saveImageActivityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        _saveImageActivityIndicator.center = CGPointMake(self.view.bounds.size.width * 0.5, self.view.bounds.size.height * 0.4);
        [self.view addSubview:_saveImageActivityIndicator];
        [_saveImageActivityIndicator startAnimating];
        
    } complete:^(UIImage *result, BOOL completed) {
        if (nil != result) {
            _imageView.image = result;
        }
        
        [self saveImageToSystemAlbum:result];
    }];
}

#pragma mark EIPhotoSDKEditorControllerDelegate
- (void)photoEditor:(EIPhotoSDKEditorController *)editor didFinishedWithImage:(UIImage *)image
{
    _imageView.image = image;
    if (nil == image) {
        _noPhotoView.hidden = NO;
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)photoEditorDidCancel:(EIPhotoSDKEditorController *)editor
{
    _imageView.image = nil;
    _noPhotoView.hidden = NO;
    [_editorSessions removeAllObjects];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark UIPopoverController for iPad
- (void)presentViewControllerInPopover:(UIViewController *)controller fromRect:(CGRect)sourceRect
{
    _popover = [[UIPopoverController alloc] initWithContentViewController:controller];
    _popover.delegate = self;
    [_popover presentPopoverFromRect:sourceRect inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

- (void)dismissPopoverWithCompletion:(void(^)(void))completion
{
    [_popover dismissPopoverAnimated:YES];
    _popover = nil;
    
    NSTimeInterval delayInSeconds = 0.5;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        completion();
    });
}

#pragma mark - UIPopoverControllerDelegate
- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    _popover = nil;
    _isImagePickerShowed = NO;
}

#pragma mark - ALAssets Helper Methods
- (UIImage *)editingResImageForAsset:(ALAsset *)asset
{
    CGImageRef image = [[asset defaultRepresentation] fullScreenImage];
    return [UIImage imageWithCGImage:image scale:1.0 orientation:UIImageOrientationUp];
}

- (UIImage *)highResImageForAsset:(ALAsset*)asset
{
    ALAssetRepresentation * representation = [asset defaultRepresentation];
    
    CGImageRef image = [representation fullResolutionImage];
    UIImageOrientation orientation = (UIImageOrientation)[representation orientation];
    CGFloat scale = [representation scale];
    
    return [UIImage imageWithCGImage:image scale:scale orientation:orientation];
}

#pragma mark UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    NSURL *assetURL = info[UIImagePickerControllerReferenceURL];
    void(^completion)(void)  = ^(void){
        _isImagePickerShowed = NO;
        ALAssetsLibrary *assetsLibrary = [[ALAssetsLibrary alloc] init];
        [assetsLibrary assetForURL:assetURL resultBlock:^(ALAsset *asset) {
            if (asset){
                UIImage *screenImage = [self editingResImageForAsset:asset];
                UIImage *fullResolutionImage = [self highResImageForAsset:asset];
                [self launchPhotoEditorWithImage:screenImage highResolutionImage:fullResolutionImage];
                _noPhotoView.hidden = YES;
            }
        } failureBlock:^(NSError *error) {
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                        message:NSLocalizedString(@"Please enable access to your device's photos.", nil)
                                       delegate:nil
                              cancelButtonTitle:NSLocalizedString(@"OK", nil)
                              otherButtonTitles:nil] show];
        }];
    };
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self dismissViewControllerAnimated:YES completion:completion];
    }else{
        [self dismissPopoverWithCompletion:completion];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:^{
        _isImagePickerShowed = NO;
    }];
    _imageView.image = nil;
    _noPhotoView.hidden = NO;
}

#pragma saveImageToSystemAlbum
- (void)saveImageToSystemAlbum:(UIImage *)image
{
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    [_saveImageActivityIndicator stopAnimating];
    [_saveImageActivityIndicator removeFromSuperview];
    _saveImageActivityIndicator = nil;
    
    self.view.userInteractionEnabled = YES;
}



- (void)setupView
{
    [self setupBottombar];
    
    CGRect imageViewFrame = self.view.bounds;
    static const CGFloat padding = 6.f;
    imageViewFrame.origin.x = padding;
    imageViewFrame.size.width = (imageViewFrame.size.width - padding * 2);
    
    CGRect navBarFrame = self.navigationController.navigationBar.frame;
    imageViewFrame.origin.y = padding + navBarFrame.size.height;
    imageViewFrame.size.height -= kBottombarHeight + padding * 2 + navBarFrame.size.height;
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        CGRect statusFrame = [UIApplication sharedApplication].statusBarFrame;
        imageViewFrame.origin.y += navBarFrame.origin.y;
        imageViewFrame.size.height -= statusFrame.size.height;
    }
    
    _noPhotoView = [[UIImageView alloc] initWithFrame:imageViewFrame];
    _noPhotoView.contentMode = UIViewContentModeCenter;
    _noPhotoView.image = [UIImage imageNamed:@"sdk_edit_fotor_sdk.png"];
    _noPhotoView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_noPhotoView];
    
    _imageView = [[UIImageView alloc] initWithFrame:imageViewFrame];
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_imageView];
}

- (void)setupBottombar
{
    CGRect bottomContainerFrame = CGRectMake(0, self.view.bounds.size.height - kBottombarHeight, self.view.bounds.size.width, kBottombarHeight);
    UIView* bottomContainer = [[UIView alloc] initWithFrame:bottomContainerFrame];
    bottomContainer.backgroundColor = [UIColor colorWithRed:65.f/255.f green:72.f/255.f blue:80.f/255.f alpha:0.9];
    bottomContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:bottomContainer];
    
    // right button
    MyButton *buttonEditor = [[MyButton alloc] init];  //Image editor
    buttonEditor.titleLabel.font = [UIFont fontWithName:@"Helvetica-Light" size:16];
    buttonEditor.bounds = CGRectMake(0, 0, self.view.bounds.size.width / 2, bottomContainerFrame.size.height);
    [buttonEditor setTitle:NSLocalizedString(@"Edit sample image", nil) forState:UIControlStateNormal];
    [buttonEditor addTarget:self action:@selector(didClickButtonEditor) forControlEvents:UIControlEventTouchUpInside];
    buttonEditor.backgroundColor = [UIColor clearColor];
    buttonEditor.highlightBackgroudColor = [UIColor colorWithRed:28.f/255.f green:31.f/255.f blue:39.f/255.f alpha:0.6];
    buttonEditor.selectedBackgroundColor = [UIColor colorWithRed:28.f/255.f green:31.f/255.f blue:39.f/255.f alpha:0.6];
    buttonEditor.center = CGPointMake(bottomContainerFrame.size.width - buttonEditor.bounds.size.width * 0.5, bottomContainerFrame.size.height * 0.5);
    UIColor* normalColor = [UIColor colorWithRed:179.f/255.f green:194.f/255.f blue:214.f/255.f alpha:1.0];
    UIColor* selectedColor = [UIColor colorWithRed:0.f green:192.f/255.f blue:255.f/255.f alpha:1.0];
    [buttonEditor setTitleColor:normalColor forState:UIControlStateNormal];
    [buttonEditor setTitleColor:selectedColor forState:UIControlStateHighlighted];
    [buttonEditor setTitleColor:selectedColor forState:UIControlStateSelected];
    [buttonEditor setTitleColor:selectedColor forState:UIControlStateHighlighted | UIControlStateSelected];
    buttonEditor.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
    [bottomContainer addSubview:buttonEditor];
    
    // letf button
    MyButton *buttonPicker = [[MyButton alloc] init];  //Image selector
    buttonPicker.bounds  = buttonEditor.bounds;
    buttonPicker.titleLabel.font = buttonEditor.titleLabel.font;
    [buttonPicker setTitle:NSLocalizedString(@"Select an image", nil) forState:UIControlStateNormal];
    [buttonPicker addTarget:self action:@selector(didClickButtonPicker:) forControlEvents:UIControlEventTouchUpInside];
    buttonPicker.backgroundColor = [UIColor clearColor];
    buttonPicker.highlightBackgroudColor = buttonEditor.highlightBackgroudColor;
    buttonPicker.selectedBackgroundColor = buttonEditor.selectedBackgroundColor;
    buttonPicker.center = CGPointMake(buttonPicker.bounds.size.width * 0.5, bottomContainerFrame.size.height * 0.5);
    [buttonPicker setTitleColor:normalColor forState:UIControlStateNormal];
    [buttonPicker setTitleColor:selectedColor forState:UIControlStateHighlighted];
    [buttonPicker setTitleColor:selectedColor forState:UIControlStateSelected];
    [buttonPicker setTitleColor:selectedColor forState:UIControlStateHighlighted | UIControlStateSelected];
    buttonPicker.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
    [bottomContainer addSubview:buttonPicker];
    
    UIView* splitView = [[UIView alloc] initWithFrame:CGRectMake(buttonPicker.bounds.size.width, 0, 1, bottomContainerFrame.size.height)];
    splitView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.3];
    splitView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [bottomContainer addSubview:splitView];
}

@end
