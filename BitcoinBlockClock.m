#import "BitcoinBlockClock.h"
#import <WebKit/WebKit.h>

@implementation BitcoinBlockClock
    
    static NSString * const bitcoinClockModule = @"com.bitcoinblockclock";
    
    // The bulk of this code was copied from, and Copyright © 2022 Christopher Newton, www.github.com/chrstphrknwtn
    // Used here with permission. License: https://github.com/chrstphrknwtn/word-clock-screensaver/blob/master/license
    
- (id)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    if (!(self = [super initWithFrame:frame isPreview:isPreview])) return nil;
    
    // Preference Defaults
    ScreenSaverDefaults *defaults;
    defaults = [ScreenSaverDefaults defaultsForModuleWithName:bitcoinClockModule];
    
    [defaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                                @"0", @"screenDisplayOption", // Default to show only on primary display
                                @"2", @"timeZoneOption",
                                nil]];
    
    // Webview
    NSURL* indexHTMLDocumentURL = [NSURL URLWithString:[[[NSURL fileURLWithPath:[[NSBundle bundleForClass:self.class].resourcePath stringByAppendingString:@"/Webview/index.html"] isDirectory:NO] description] stringByAppendingFormat:@"?screensaver=1%@", self.isPreview ? @"&is_preview=1" : @""]];
    
    WebView* webView = [[WebView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height)];
    webView.drawsBackground = NO; // Avoids a "white flash" just before the index.html file has loaded
    [webView.mainFrame loadRequest:[NSURLRequest requestWithURL:indexHTMLDocumentURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0]];
    
    // Nuke variable when declared in index.html (which is required for the non-screensaver version)...
    
    NSString * javascriptString = @"document.getElementById('initialVariables').innerHTML='';";
    [webView stringByEvaluatingJavaScriptFromString:javascriptString];
    
    // Pass options from config sheet to index.js...

    switch ([defaults integerForKey:@"timeZoneOption"]) {
        case 0: {
            NSString * javascriptString = @"const timeZoneOption = 'timeZoneAbbrv';";
            [webView stringByEvaluatingJavaScriptFromString:javascriptString];
            break;
        }
        case 1: {
            NSString * javascriptString = @"const timeZoneOption = 'timeZoneCity';";
            [webView stringByEvaluatingJavaScriptFromString:javascriptString];
            break;
        }
        case 2: {
            NSString * javascriptString = @"const timeZoneOption = 'timeZoneDisable';";
            [webView stringByEvaluatingJavaScriptFromString:javascriptString];
            break;
        }

    }
    
    // Show on screens based on preferences
    NSArray* screens = [NSScreen screens];
    NSScreen* primaryScreen = [screens objectAtIndex:0];
    
    switch ([defaults integerForKey:@"screenDisplayOption"]) {
        // Primary screen (System Preferences > Displays).
        // The screen the menubar is shown on under 'arrangement'
        case 0:
        if ((primaryScreen.frame.origin.x == frame.origin.x) || isPreview) {
            [self addSubview:webView];
        }
        break;
        // Last Focussed Screen
        // This _sometimes_ results in nothing being shown when previewing in system prefs.
        case 1:
        if (([NSScreen mainScreen].frame.origin.x == frame.origin.x) || isPreview) {
            [self addSubview:webView];
        }
        break;
        // All Screens
        case 2:
        [self addSubview:webView];
        break;
        default:
        [self addSubview:webView];
        break;
    }
    
    return self;
}
    
#pragma mark - ScreenSaverView
    
- (void)animateOneFrame { [self stopAnimation]; }
    
#pragma mark - Config
    // http://cocoadevcentral.com/articles/000088.php
    
- (BOOL)hasConfigureSheet { return YES; }
    
- (NSWindow *)configureSheet
    {
        ScreenSaverDefaults *defaults;
        defaults = [ScreenSaverDefaults defaultsForModuleWithName:bitcoinClockModule];
        
        if (!configSheet)
        {
            //        XCode deprecated warning is fixed with this code, but the configuration pane no longer works. Build with Xcode 9.2.
            //        if (![[NSBundle mainBundle] loadNibNamed:@"ConfigureSheet" owner:self topLevelObjects:nil])
            if (![NSBundle loadNibNamed:@"ConfigureSheet" owner:self]) // extra note: if you Build this project with Xcode 12 & ignore the deprecated error, the config panel works in macOS11.4 System Preferences! Weird.
            {
                NSLog( @"Failed to load configure sheet." );
            }
        }
        
        [screenDisplayOption selectItemAtIndex:[defaults integerForKey:@"screenDisplayOption"]];
        [timeZoneOption selectItemAtIndex:[defaults integerForKey:@"timeZoneOption"]];
        
        return configSheet;
    }
    
- (IBAction)cancelClick:(id)sender
    {
        [[NSApplication sharedApplication] endSheet:configSheet];
    }
    
- (IBAction) okClick: (id)sender
    {
        ScreenSaverDefaults *defaults;
        defaults = [ScreenSaverDefaults defaultsForModuleWithName:bitcoinClockModule];
        
        // Update our defaults
        [defaults setInteger:[screenDisplayOption indexOfSelectedItem] forKey:@"screenDisplayOption"];
        [defaults setInteger:[timeZoneOption indexOfSelectedItem] forKey:@"timeZoneOption"];
        
        // Save the settings to disk
        [defaults synchronize];
        
        // Close the sheet
        [[NSApplication sharedApplication] endSheet:configSheet];
    }
    
#pragma mark - WebFrameLoadDelegate
    
- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame {
    NSLog(@"%@ error=%@", NSStringFromSelector(_cmd), error);
}
    
#pragma mark Focus Overrides
    
- (NSView *)hitTest:(NSPoint)aPoint {return self;}
    //- (void)keyDown:(NSEvent *)theEvent {return;}
    //- (void)keyUp:(NSEvent *)theEvent {return;}
- (void)mouseDown:(NSEvent *)theEvent {return;}
- (void)mouseUp:(NSEvent *)theEvent {return;}
- (void)mouseDragged:(NSEvent *)theEvent {return;}
- (void)mouseEntered:(NSEvent *)theEvent {return;}
- (void)mouseExited:(NSEvent *)theEvent {return;}
- (BOOL)acceptsFirstResponder {return YES;}
- (BOOL)resignFirstResponder {return NO;}
    
    @end

