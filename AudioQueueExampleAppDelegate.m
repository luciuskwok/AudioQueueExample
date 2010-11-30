//
//  AudioQueueExampleAppDelegate.m
//  AudioQueueExample
//
//  Created by Lucius Kwok on 11/26/10.
//  Copyright 2010 Felt Tip Inc. All rights reserved.
//

#import "AudioQueueExampleAppDelegate.h"


// Constants
const Float64 kSampleRate = 44100.0;
const NSUInteger kBufferByteSize = 2048;




@implementation AudioQueueExampleAppDelegate

@synthesize window, inputLevelMeter;

#pragma mark Input

void InputBufferCallaback (void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer, const AudioTimeStamp *inStartTime, UInt32 inNumPackets, const AudioStreamPacketDescription* inPacketDesc) 
{
	[(AudioQueueExampleAppDelegate *)inUserData processInputBuffer:inBuffer queue:inAQ];
}

- (void)startInputAudioQueue {
	OSStatus err;
	int i;
	
	// Set up stream format fields
	AudioStreamBasicDescription streamFormat;
	streamFormat.mSampleRate = kSampleRate;
	streamFormat.mFormatID = kAudioFormatLinearPCM;
	streamFormat.mFormatFlags = kLinearPCMFormatFlagIsFloat | kAudioFormatFlagsNativeEndian;
	streamFormat.mBitsPerChannel = 32;
	streamFormat.mChannelsPerFrame = 1;
	streamFormat.mBytesPerPacket = 4 * streamFormat.mChannelsPerFrame;
	streamFormat.mBytesPerFrame = 4 * streamFormat.mChannelsPerFrame;
	streamFormat.mFramesPerPacket = 1;
	streamFormat.mReserved = 0;
	
	// New input queue
	err = AudioQueueNewInput (&streamFormat, InputBufferCallaback, self, nil, nil, 0, &inputQueue);
	if (err != noErr) NSLog(@"AudioQueueNewInput() error: %d", err);
	
	// Enqueue buffers
	AudioQueueBufferRef buffer;
	for (i=0; i<3; i++) {
		err = AudioQueueAllocateBuffer (inputQueue, kBufferByteSize, &buffer); 
		if (err == noErr) {
			err = AudioQueueEnqueueBuffer (inputQueue, buffer, 0, nil);
			if (err != noErr) NSLog(@"AudioQueueEnqueueBuffer() error: %d", err);
		} else {
			NSLog(@"AudioQueueAllocateBuffer() error: %d", err); 
			return;
		}
	}
	
	// Start queue
	err = AudioQueueStart(inputQueue, nil);
	if (err != noErr) NSLog(@"AudioQueueStart() error: %d", err);
}

-(void) processInputBuffer: (AudioQueueBufferRef) buffer queue:(AudioQueueRef) queue {
	// FInd the peak amplitude.
	int frame, count = buffer->mAudioDataByteSize / sizeof (Float32);
	Float32 *audioData = buffer->mAudioData;
	Float32 max = 0.0;
	Float32 sampleValue;
	for (frame = 0; frame < count; frame++) {
		sampleValue = audioData[frame];
		if (sampleValue < 0.0f)
			sampleValue = -sampleValue;
		if (max < sampleValue) 
			max = sampleValue;
	}
	
	// Update level meter on main thread
	double db = 20 * log10 (max);
	NSNumber *peakAmplitudeNumber = [[NSNumber alloc] initWithDouble:db];
	[self performSelectorOnMainThread:@selector(setInputLevelMeterValue:) withObject:peakAmplitudeNumber waitUntilDone:NO];
	
	// Re-enqueue buffer.
	OSStatus err = AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
	if (err != noErr)
		NSLog(@"AudioQueueEnqueueBuffer() error %d", err);
}

- (void)setInputLevelMeterValue:(NSNumber *)number {
	[inputLevelMeter setDoubleValue:[number doubleValue]];
	[number release];
}

#pragma mark Output

void OutputBufferCallback (void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) 
{
	[(AudioQueueExampleAppDelegate *)inUserData processOutputBuffer:inBuffer queue:inAQ];
}

- (void)startOutputAudioQueue {
	OSStatus err;
	int i;
	
	// Set up stream format fields
	AudioStreamBasicDescription streamFormat;
	streamFormat.mSampleRate = kSampleRate;
	streamFormat.mFormatID = kAudioFormatLinearPCM;
	streamFormat.mFormatFlags = kLinearPCMFormatFlagIsFloat | kAudioFormatFlagsNativeEndian;
	streamFormat.mBitsPerChannel = 32;
	streamFormat.mChannelsPerFrame = 1;
	streamFormat.mBytesPerPacket = 4 * streamFormat.mChannelsPerFrame;
	streamFormat.mBytesPerFrame = 4 * streamFormat.mChannelsPerFrame;
	streamFormat.mFramesPerPacket = 1;
	streamFormat.mReserved = 0;

	// New output queue ---- PLAYBACK ----
	err = AudioQueueNewOutput (&streamFormat, OutputBufferCallback, self, nil, nil, 0, &outputQueue);
	if (err != noErr) NSLog(@"AudioQueueNewOutput() error: %d", err);
	
	// Enqueue buffers
	AudioQueueBufferRef buffer;
	for (i=0; i<3; i++) {
		err = AudioQueueAllocateBuffer (outputQueue, kBufferByteSize, &buffer); 
		if (err == noErr) {
			[self generateTone: buffer];
			err = AudioQueueEnqueueBuffer (outputQueue, buffer, 0, nil);
			if (err != noErr) NSLog(@"AudioQueueEnqueueBuffer() error: %d", err);
		} else {
			NSLog(@"AudioQueueAllocateBuffer() error: %d", err); 
			return;
		}
	}
		
	// Start queue
	err = AudioQueueStart(outputQueue, nil);
	if (err != noErr) NSLog(@"AudioQueueStart() error: %d", err);
}

- (void) processOutputBuffer: (AudioQueueBufferRef) buffer queue:(AudioQueueRef) queue {
	// Fill buffer.
	[self generateTone: buffer];
	
	// Re-enqueue buffer.
	OSStatus err = AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
	if (err != noErr)
		NSLog(@"AudioQueueEnqueueBuffer() error %d", err);
}

- (void) generateTone: (AudioQueueBufferRef) buffer {
	[noteLock lock];
	
	if (noteAmplitude == 0.0) {
		// Skip rendering audio if the amplitude is zero.
		memset(buffer->mAudioData, 0, buffer->mAudioDataBytesCapacity);
	} else {
		// Generate a sine wave.
		int frame, count = buffer->mAudioDataBytesCapacity / sizeof (Float32);
		Float32 *audioData = buffer->mAudioData;
		double x, y;
		
		for (frame = 0; frame < count; frame++) {
			x = noteFrame * noteFrequency / kSampleRate;
			y = sin (x * 2.0 * M_PI) * noteAmplitude;
			audioData[frame] = y;
			
			// Advance counters
			noteAmplitude -= noteDecay;
			if (noteAmplitude < 0.0)
				noteAmplitude = 0.0;
			noteFrame++;
		}
	}
	
	// Don't forget to set the actual size of the data in the buffer.
	buffer->mAudioDataByteSize = buffer->mAudioDataBytesCapacity;
	
	[noteLock unlock];
}

- (IBAction)playNote:(id)sender {
	double tag = [sender tag];
	[noteLock lock];
	noteFrame = 0;
	noteFrequency = tag / 10.0;
	noteAmplitude = 1.0;
	noteDecay = 1 / 44100.0;
	[noteLock unlock];
}

#pragma mark -

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	noteLock = [[NSLock alloc] init]; // Because the app delegate is never dealloc'd, there's no release in this class.
	
	[self startInputAudioQueue];
	[self startOutputAudioQueue];
}

- (void)cleanUp {
	OSStatus err;
	
	err = AudioQueueDispose (inputQueue, YES); // Also disposes of its buffers
	if (err != noErr) NSLog(@"AudioQueueDispose() error: %d", err);
	inputQueue = nil;
	
	err = AudioQueueDispose (outputQueue, NO); // Also disposes of its buffers
	if (err != noErr) NSLog(@"AudioQueueDispose() error: %d", err);
	outputQueue = nil;
}

@end
