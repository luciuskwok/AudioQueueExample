//
//  AudioQueueExampleAppDelegate.h
//  AudioQueueExample
//
//  Created by Lucius Kwok on 11/26/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioToolbox.h>


@interface AudioQueueExampleAppDelegate : NSObject <NSApplicationDelegate> {
	NSWindow *window;
	NSLevelIndicator *inputLevelMeter;

	// AudioQueue
	AudioQueueRef inputQueue;
	AudioQueueRef outputQueue;
	
	// Note player
	double noteFrequency;
	double noteAmplitude;
	double noteDecay;
	int noteFrame;
	NSLock *noteLock;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSLevelIndicator *inputLevelMeter;


// Input
- (void) processInputBuffer: (AudioQueueBufferRef) buffer queue:(AudioQueueRef) queue;

// Output
- (void) processOutputBuffer: (AudioQueueBufferRef) buffer queue: (AudioQueueRef) queue;
- (void) generateTone: (AudioQueueBufferRef) buffer;
- (IBAction)playNote:(id)sender;

@end
