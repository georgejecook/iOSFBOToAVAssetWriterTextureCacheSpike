

#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "TestViewController.h"


/////////////////////////////////////////////////////////////////
// This data type is used to store information for each vertex
typedef struct
{
    GLKVector3 positionCoords;
}
        SceneVertex;

/////////////////////////////////////////////////////////////////
// Define vertex data for a triangle to use in example
static const SceneVertex vertices[] =
        {
                {{-1.0f, -1.0f, 1.0}}, // lower left corner
                {{1.0f, -1.0f, 0.5}}, // lower right corner
                {{1.0f, 1.0f, 0.0}}  // upper left corner
        };


@interface TestViewController ()

@property(nonatomic, readwrite, assign) CVOpenGLESTextureCacheRef videoTextureCache;
@property(strong, nonatomic) GLKTextureInfo *background;
@property(nonatomic, strong) AVAssetWriter *assetWriter;

@property(nonatomic) BOOL isRecording;

@property(nonatomic, strong) AVAssetWriterInput *assetWriterVideoInput;

@property(nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *assetWriterPixelBufferInput;

@property(nonatomic, assign) CFAbsoluteTime startTime;

@property(nonatomic, strong) GLKView *glkView;

@property(nonatomic, strong) GLKBaseEffect *screenGLEffect;
@property(nonatomic, strong) GLKBaseEffect *FBOGLEffect;

@property(nonatomic, strong) NSTimer *recordingTimer;

- (BOOL)isRetina;
@end


@implementation TestViewController
{
    CVOpenGLESTextureCacheRef _writerTextureCache;
    GLuint _writerRenderFrameBuffer;
    GLuint vertexBufferID;

    EAGLContext *_writerContext;
    CVOpenGLESTextureRef _writerTexture;
}

@synthesize videoTextureCache = _videoTextureCache;

/////////////////////////////////////////////////////////////////
// 
- (void)viewDidLoad
{
    [super viewDidLoad];
    NSLog(@"viewDidLoad");
    // Verify the type of view created automatically by the
    // Interface Builder storyboard
    [self createDrawingContextAndTextureCache];
    //[self createBasicDrawingEffectInCurrentContext];
}

- (void)createDrawingContextAndTextureCache
{
    self.glkView = (GLKView *) self.view;
    NSAssert([self.glkView isKindOfClass:[GLKView class]], @"View controller's view is not a GLKView");

    // Create an OpenGL ES 2.0 context and provide it to the
    // view
    self.glkView.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    self.glkView.layer.opaque = YES;

    CAEAGLLayer *eaglLayer = (CAEAGLLayer *) self.glkView.layer;
    eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking,
                                                         kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                                         nil];

    // Make the new context current
    [EAGLContext setCurrentContext:self.glkView.context];
    // Set the background color
    glClearColor(
            0.0f, // Red
            0.0f, // Green
            0.0f, // Blue
            0.0f);// Alpha
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    //  Create a new CVOpenGLESTexture cache
    CVReturn err = CVOpenGLESTextureCacheCreate(
            kCFAllocatorDefault,
            NULL,
            (__bridge CVEAGLContext) ((__bridge void *) self.glkView.context),
            NULL,
            &_videoTextureCache);

    if (err)
    {
        NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
    }
}


- (GLKBaseEffect *)testEffect
{
    GLKBaseEffect *basicGLEffect = [[GLKBaseEffect alloc] init];

    self.background = [GLKTextureLoader textureWithCGImage:[[UIImage imageNamed:@"Elephant.jpg"] CGImage]
                                                   options:nil error:NULL];
    basicGLEffect.texture2d0.name = self.background.name;
    basicGLEffect.texture2d0.target = self.background.target;
    return basicGLEffect;
}

- (GLKBaseEffect *)createBasicDrawingEffectInCurrentContext
{
    GLKBaseEffect *basicGLEffect = [[GLKBaseEffect alloc] init];

    self.background = [GLKTextureLoader textureWithCGImage:[[UIImage imageNamed:@"Elephant.jpg"] CGImage]
                                                   options:nil error:NULL];
    basicGLEffect.texture2d0.name = self.background.name;
    basicGLEffect.texture2d0.target = self.background.target;


    basicGLEffect.useConstantColor = GL_TRUE;
    basicGLEffect.constantColor = GLKVector4Make(
            .5f, // Red
            1.0f, // Green
            .5f, // Blue
            1.0f);// Alpha

    // Set the background color stored in the current context
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f); // background color

    // Generate, bind, and initialize contents of a buffer to be
    // stored in GPU memory
    glGenBuffers(1,                // STEP 1
            &vertexBufferID);
    glBindBuffer(GL_ARRAY_BUFFER,  // STEP 2
            vertexBufferID);
    glBufferData(                  // STEP 3
            GL_ARRAY_BUFFER,  // Initialize buffer contents
            sizeof(vertices), // Number of bytes to copy
            vertices,         // Address of bytes to copy
            GL_STATIC_DRAW);  // Hint: cache in GPU memory
    return basicGLEffect;
}


/////////////////////////////////////////////////////////////////
// 
- (void)viewDidUnload
{
    [super viewDidUnload];

    // Make the view's context current
    GLKView *view = (GLKView *) self.view;
    [EAGLContext setCurrentContext:view.context];

    // Stop using the context created in -viewDidLoad
    ((GLKView *) self.view).context = nil;
    [EAGLContext setCurrentContext:nil];
}

//////////////////////////////////////////////////////////////
#pragma mark drawing
//////////////////////////////////////////////////////////////

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    [super glkView:view drawInRect:rect];
    [self drawBasicGLToScreen];
}

- (void)drawBasicGLToScreen
{

    [EAGLContext setCurrentContext:self.glkView.context];
    if (!self.screenGLEffect)
    {
//        self.screenGLEffect = [self createBasicDrawingEffectInCurrentContext];
        self.screenGLEffect = [self testEffect];
    }

    CGSize realAspectRatio = self.view.bounds.size;

    size_t frameWidth = 640;
    size_t frameHeight = 480;


    glDisable(GL_DEPTH_TEST);
    glBindTexture(GL_TEXTURE_2D, 0);

//    glClearColor(1, 0, 1, 1);
//    glClear(GL_COLOR_BUFFER_BIT);

    const GLfloat *squareVertices = [self isRetina] ? [self retinaVerticies] : [self nonRetinaVerticies];

    CGRect textureSamplingRect = [self textureSamplingRectForCroppingTextureWithAspectRatio:CGSizeMake(frameWidth, frameHeight)
                                                                              toAspectRatio:realAspectRatio];

    GLfloat textureVertices[] =
            {
                    CGRectGetMinX(textureSamplingRect), CGRectGetMaxY(textureSamplingRect),
                    CGRectGetMaxX(textureSamplingRect), CGRectGetMaxY(textureSamplingRect),
                    CGRectGetMinX(textureSamplingRect), CGRectGetMinY(textureSamplingRect),
                    CGRectGetMaxX(textureSamplingRect), CGRectGetMinY(textureSamplingRect),
            };

    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE_MINUS_DST_ALPHA, GL_DST_ALPHA);
    [self.screenGLEffect prepareToDraw];
    [self renderWithSquareVertices:squareVertices
                   textureVertices:textureVertices];


    glFlush();

    // Present
    GLKView *glkView = (GLKView *) self.view;
    [glkView.context presentRenderbuffer:GL_RENDERBUFFER];


}

//
//- (void)drawBasicGLToScreen
//{
//    [EAGLContext setCurrentContext:self.glkView.context];
//    if (!self.screenGLEffect)
//    {
//        self.screenGLEffect = [self createBasicDrawingEffectInCurrentContext];
//    }
//
//    glClear(GL_COLOR_BUFFER_BIT);
//    [self.screenGLEffect prepareToDraw];
//
//    // Clear Frame Buffer (erase previous drawing)
//
//    // Enable use of positions from bound vertex buffer
//    glEnableVertexAttribArray(      // STEP 4
//            GLKVertexAttribPosition);
//
//    glVertexAttribPointer(          // STEP 5
//            GLKVertexAttribPosition,
//            3,                   // three components per vertex
//            GL_FLOAT,            // data is floating point
//            GL_FALSE,            // no fixed point scaling
//            sizeof(SceneVertex), // no gaps in data
//            NULL);               // NULL tells GPU to start at
//    // beginning of bound buffer
//
//    // Draw triangles using the first three vertices in the
//    // currently bound vertex buffer
//    glDrawArrays(GL_TRIANGLES,      // STEP 6
//            0,  // Start with first vertex in currently bound buffer
//            3); // Use three vertices from currently bound buffer
//    glFlush();
//
//    // Present
//    GLKView *glkView = (GLKView *) self.view;
//    [glkView.context presentRenderbuffer:GL_RENDERBUFFER];
//
//
//}

//////////////////////////////////////////////////////////////
#pragma mark AVWriter setup
//////////////////////////////////////////////////////////////


- (NSString *)tempFilePath
{
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/output2.m4v"];
}


- (void)removeTempFile
{
    NSString *path = [self tempFilePath];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    BOOL exists = [fileManager fileExistsAtPath:path];
    NSLog(@">>>remove %@ Exists %d", path, exists);

    NSError *error;
    unlink([path UTF8String]);

    NSLog(@">>>AFTER REMOVE %@ Exists %d %@", path, exists, error);

}

- (void)createWriter
{
    //My setup code is based heavily on the GPUImage project, https://github.com/BradLarson/GPUImage so some of these dictionary names and structure are similar to the code from that project - I recommend you check it out if you are interested in Video filtering/recording
    [self removeTempFile];

    NSError *error;
    self.assetWriter = [[AVAssetWriter alloc]
                                       initWithURL:[NSURL fileURLWithPath:[self tempFilePath]]
                                          fileType:AVFileTypeQuickTimeMovie
                                             error:&error];

    if (error)
    {
        NSLog(@"Couldn't create writer, %@", error.localizedDescription);
        return;
    }

    NSDictionary *outputSettings = @{
            AVVideoCodecKey : AVVideoCodecH264,
            AVVideoWidthKey : @640,
            AVVideoHeightKey : @480
    };

    self.assetWriterVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                    outputSettings:outputSettings];

    self.assetWriterVideoInput.expectsMediaDataInRealTime = YES;

    NSDictionary *sourcePixelBufferAttributesDictionary = @{(id) kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
                                                            (id) kCVPixelBufferWidthKey : @640,
                                                            (id) kCVPixelBufferHeightKey : @480};

    self.assetWriterPixelBufferInput = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.assetWriterVideoInput
                                                                                                        sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];

    self.assetWriterVideoInput.transform = CGAffineTransformMakeScale(1, -1);

    if ([_assetWriter canAddInput:self.assetWriterVideoInput])
    {
        [_assetWriter addInput:self.assetWriterVideoInput];
    } else
    {
        NSLog(@"can't add video writer input %@", self.assetWriterVideoInput);
    }
    /*
    _assetWriterAudioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:nil];
    if ([_assetWriter canAddInput:_assetWriterAudioInput]) {
        [_assetWriter addInput:_assetWriterAudioInput];
        _assetWriterAudioInput.expectsMediaDataInRealTime = YES;
    }
     */
}


- (void)writeMovieToLibraryWithPath:(NSURL *)path
{
    NSLog(@"writing %@ to library", path);
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library writeVideoAtPathToSavedPhotosAlbum:path
                                completionBlock:^(NSURL *assetURL, NSError *error) {
                                    if (error)
                                    {
                                        NSLog(@"Error saving to library%@", [error localizedDescription]);
                                    } else
                                    {
                                        NSLog(@"SAVED %@ to photo lib", path);
                                    }
                                }];
}


//////////////////////////////////////////////////////////////
#pragma mark touch handling
//////////////////////////////////////////////////////////////

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSLog(@"did touch");
    [super touchesEnded:touches withEvent:event];
    if (self.isRecording)
    {
        [self finishRecording];
    } else
    {
        [self startRecording];
    }
}

//////////////////////////////////////////////////////////////
#pragma mark recording
//////////////////////////////////////////////////////////////


- (void)startRecording;
{
    NSLog(@"started recording");
#warning debugging startrecording
//    NSLog(@"bypassing usual write method");
//      if (![assetWriter startWriting]){
//        NSLog(@"writer not started %@, %d", assetWriter.error, assetWriter.status);
//    }
    self.startTime = CFAbsoluteTimeGetCurrent();

    [self createWriter];
    [self.assetWriter startWriting];
    [self.assetWriter startSessionAtSourceTime:kCMTimeZero];

    NSAssert([self.assetWriterPixelBufferInput pixelBufferPool], @"writerpixelbuffer input has no pools");

    if (!_writerContext)
    {
        _writerContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        if (!_writerContext || ![EAGLContext setCurrentContext:_writerContext])
        {
            NSLog(@"Problem with OpenGL context.");

            return;
        }
//        /**DEBUG SET VIEW **/
//        self.glkView = (GLKView *) self.view;
//        NSAssert([self.glkView isKindOfClass:[GLKView class]], @"View controller's view is not a GLKView");
//
//        // Create an OpenGL ES 2.0 context and provide it to the
//        // view
//        self.glkView.context = _writerContext;
//        self.glkView.layer.opaque = YES;
//
//        CAEAGLLayer *eaglLayer = (CAEAGLLayer *) self.glkView.layer;
//        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
//                                                             [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking,
//                                                             kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
//                                                             nil];
//
//        // Make the new context current
//        // Set the background color
//        glClearColor(
//                0.0f, // Red
//                0.0f, // Green
//                0.0f, // Blue
//                0.0f);// Alpha
//        glEnable(GL_BLEND);
//        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
//
//        //  Create a new CVOpenGLESTexture cache
//        CVReturn err = CVOpenGLESTextureCacheCreate(
//                kCFAllocatorDefault,
//                NULL,
//                (__bridge CVEAGLContext) ((__bridge void *) self.glkView.context),
//                NULL,
//                &_videoTextureCache);
//
//        if (err)
//        {
//            NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
//        }
    }


    [EAGLContext setCurrentContext:_writerContext];

    NSLog(@"Creating FBO");
    [self createDataFBOUsingGPUImagesMethod];
//    [self createDataFBO];
    self.isRecording = YES;
    NSLog(@"Recording is started");

    self.recordingTimer = [NSTimer scheduledTimerWithTimeInterval:1 / 30
                                                           target:self
                                                         selector:@selector(tick:)
                                                         userInfo:nil repeats:YES];
}

- (void)tick:(id)tick
{
    [self drawBasicGLTOFBOForWriting];
}

- (void)finishRecording;
{
    [self.recordingTimer invalidate];
    self.recordingTimer = nil;

    NSLog(@"finished recording");
    if (self.assetWriter.status == AVAssetWriterStatusCompleted || !self.isRecording)
    {
        NSLog(@"already completed ingnoring");
        return;
    }

    NSLog(@"Asset writer writing");
    self.isRecording = NO;
//    runOnMainQueueWithoutDeadlocking(^{
    NSLog(@"markng inputs as finished");
    //TODO - these cause an error
    [self.assetWriterVideoInput markAsFinished];
    __weak TestViewController *blockSelf = self;

    [self.assetWriter finishWritingWithCompletionHandler:^{
        if (self.assetWriter.error == nil)
        {
            NSLog(@"saved ok - writing to lib");
            [self writeMovieToLibraryWithPath:[NSURL fileURLWithPath:[self tempFilePath]]];
        } else
        {
            NSLog(@" did not save due to error %@", self.assetWriter.error);
        }
    }];
//    });
}


- (void)drawBasicGLTOFBOForWriting
{
    if (!self.isRecording)
    {
        return;
    }

//    size_t frameWidth = CVPixelBufferGetWidth(pixelBuffer);
//    size_t frameHeight = CVPixelBufferGetHeight(pixelBuffer);
    CGSize realAspectRatio = self.view.bounds.size;

    size_t frameWidth = 640;
    size_t frameHeight = 480;

    [EAGLContext setCurrentContext:_writerContext];
    if (!self.FBOGLEffect)
    {
        self.FBOGLEffect = [self testEffect];
    }
    glClearColor(0, 1, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);

    glDisable(GL_DEPTH_TEST);
    glBindFramebuffer(GL_FRAMEBUFFER, _writerRenderFrameBuffer);
    glBindTexture(GL_TEXTURE_2D, 0);


    const GLfloat *squareVertices = [self isRetina] ? [self retinaVerticies] : [self nonRetinaVerticies];

    CGRect textureSamplingRect = [self textureSamplingRectForCroppingTextureWithAspectRatio:CGSizeMake(frameWidth, frameHeight)
                                                                              toAspectRatio:realAspectRatio];

    GLfloat textureVertices[] =
            {
                    CGRectGetMinX(textureSamplingRect), CGRectGetMaxY(textureSamplingRect),
                    CGRectGetMaxX(textureSamplingRect), CGRectGetMaxY(textureSamplingRect),
                    CGRectGetMinX(textureSamplingRect), CGRectGetMinY(textureSamplingRect),
                    CGRectGetMaxX(textureSamplingRect), CGRectGetMinY(textureSamplingRect),
            };

    //glDisable(GL_BLEND);
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE_MINUS_DST_ALPHA, GL_DST_ALPHA);

    [self.FBOGLEffect prepareToDraw];

    [self renderWithSquareVertices:squareVertices
                   textureVertices:textureVertices];
    glFlush();



    // Clear Frame Buffer (erase previous drawing)
    // Enable use of positions from bound vertex buffer
//    glEnableVertexAttribArray(      // STEP 4
//            GLKVertexAttribPosition);
//
//    glVertexAttribPointer(          // STEP 5
//            GLKVertexAttribPosition,
//            3,                   // three components per vertex
//            GL_FLOAT,            // data is floating point
//            GL_FALSE,            // no fixed point scaling
//            sizeof(SceneVertex), // no gaps in data
//            NULL);               // NULL tells GPU to start at
//    // beginning of bound buffer
//
//    // Draw triangles using the first three vertices in the
//    // currently bound vertex buffer
//
//    glDrawElements(GL_TRIANGLES, 3, GL_UNSIGNED_BYTE, vertices);
//
//
//    glDisable(GL_CULL_FACE);
//
//
//    glFlush();
//

    CFAbsoluteTime interval = (CFAbsoluteTimeGetCurrent() - self.startTime) * 1000;
    CMTime currentTime = CMTimeMake((int) interval, 1000);
    [self writeToFileWithTime:currentTime];
}

- (void)writeToFileWithTime:(CMTime)time
{
    if (!self.assetWriterVideoInput.readyForMoreMediaData)
    {
        NSLog(@"Had to drop a video frame");
        return;
    }
    if (kCVReturnSuccess == CVPixelBufferLockBaseAddress(_writerPixelBuffer,
            kCVPixelBufferLock_ReadOnly))
    {
        uint8_t *pixels = (uint8_t *) CVPixelBufferGetBaseAddress(_writerPixelBuffer);
        // process pixels how you like!
        BOOL success = [self.assetWriterPixelBufferInput appendPixelBuffer:_writerPixelBuffer
                                                      withPresentationTime:time];
        NSLog(@"wrote at %@ : %@", CMTimeCopyDescription(NULL, time), success ? @"YES" : @"NO");
        CVPixelBufferUnlockBaseAddress(_writerPixelBuffer, kCVPixelBufferLock_ReadOnly);
    }
}



//////////////////////////////////////////////////////////////
#pragma mark FBO setup
//////////////////////////////////////////////////////////////



- (void)createDataFBO;
{
    CVReturn res = CVPixelBufferPoolCreatePixelBuffer(NULL
            , [self.assetWriterPixelBufferInput pixelBufferPool]
            , &_writerPixelBuffer);
    if (res)
    {
        NSLog(@"error getting pixel buffer %d", res);
    }


    NSLog(@"writingcontext is %@ currentContext is %@", _writerContext, [EAGLContext currentContext]);

    // first create a texture from our renderTarget
    // textureCache will be what you previously made with CVOpenGLESTextureCacheCreate

    CVReturn error = CVOpenGLESTextureCacheCreate(
            kCFAllocatorDefault,
            NULL,
            (__bridge CVEAGLContext) ((__bridge void *) _writerContext),
            NULL,
            &_writerTextureCache);

    if (error)
    {
        NSLog(@"error CVOpenGLESTextureCacheCreate");
    }

    CVOpenGLESTextureRef renderTexture;
    error = CVOpenGLESTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            _writerTextureCache,
            _writerPixelBuffer,
            NULL, // texture attributes
            GL_TEXTURE_2D,
            GL_RGBA, // opengl format
            480,
            640,
            GL_BGRA, // native iOS format
            GL_UNSIGNED_BYTE,
            0,
            &renderTexture);
    // check err value
    if (error)
    {
        NSLog(@"error CVOpenGLESTextureCacheCreate");
    }

    // set the texture up like any other texture
    glBindTexture(CVOpenGLESTextureGetTarget(renderTexture),
            CVOpenGLESTextureGetName(renderTexture));
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    // bind the texture to the framebuffer you're going to render to
    // (boilerplate code to make a framebuffer not shown)

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
            GL_TEXTURE_2D, CVOpenGLESTextureGetName(renderTexture), 0);
    // great, now you're ready to render to your image.

    glGenFramebuffers(1, &_writerRenderFrameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _writerRenderFrameBuffer);

    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE)
    {
        NSAssert(NO, @"failed to make complete framebuffer object %x", status);
    }
}


- (void)createDataFBOUsingGPUImagesMethod;
{
    glActiveTexture(GL_TEXTURE1);
    glGenFramebuffers(1, &_writerRenderFrameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _writerRenderFrameBuffer);

    CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _writerContext, NULL, &_writerTextureCache);

    if (err)
    {
        NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreate %d", err);
    }

    // Code originally sourced from http://allmybrain.com/2011/12/08/rendering-to-a-texture-with-ios-5-texture-cache-api/


    CVPixelBufferPoolCreatePixelBuffer(NULL, [self.assetWriterPixelBufferInput pixelBufferPool], &_writerPixelBuffer);

    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _writerTextureCache, _writerPixelBuffer,
            NULL, // texture attributes
            GL_TEXTURE_2D,
            GL_RGBA, // opengl format
            640,
            480,
            GL_BGRA, // native iOS format
            GL_UNSIGNED_BYTE,
            0,
            &_writerTexture);

    if (err)
    {
        NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }


    glBindTexture(CVOpenGLESTextureGetTarget(_writerTexture), CVOpenGLESTextureGetName(_writerTexture));
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

//    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
//    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
//    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
//    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
//    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 640, 480, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
//


    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, CVOpenGLESTextureGetName(_writerTexture), 0);


    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);

    NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"Incomplete filter FBO: %d", status);
}


//////////////////////////////////////////////////////////////
#pragma mark textures
//////////////////////////////////////////////////////////////

- (void)renderWithSquareVertices:(const GLfloat *)squareVertices
                 textureVertices:(const GLfloat *)textureVertices
{
    // Update attribute values.
    glVertexAttribPointer(GLKVertexAttribPosition,
            2,
            GL_FLOAT,
            0,
            0,
            squareVertices);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribTexCoord0,
            2,
            GL_FLOAT,
            0,
            0,
            textureVertices);
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}



#pragma mark - Render Support

/////////////////////////////////////////////////////////////////
//
- (CGRect)textureSamplingRectForCroppingTextureWithAspectRatio:(CGSize)textureAspectRatio
                                                 toAspectRatio:(CGSize)croppingAspectRatio
{
    CGRect normalizedSamplingRect = CGRectZero;
    CGSize cropScaleAmount = CGSizeMake(croppingAspectRatio.width / textureAspectRatio.width, croppingAspectRatio.height / textureAspectRatio.height);
    CGFloat maxScale = fmax(cropScaleAmount.width, cropScaleAmount.height);
    CGSize scaledTextureSize = CGSizeMake(textureAspectRatio.width * maxScale, textureAspectRatio.height * maxScale);

    if (cropScaleAmount.height > cropScaleAmount.width)
    {
        normalizedSamplingRect.size.width = croppingAspectRatio.width / scaledTextureSize.width;
        normalizedSamplingRect.size.height = 1.0;
    } else
    {
        normalizedSamplingRect.size.height = croppingAspectRatio.height / scaledTextureSize.height;
        normalizedSamplingRect.size.width = 1.0;
    }

    // Center crop
    normalizedSamplingRect.origin.x = (1.0 - normalizedSamplingRect.size.width) / 2;
    normalizedSamplingRect.origin.y = (1.0 - normalizedSamplingRect.size.height) / 2;

    return normalizedSamplingRect;
}


- (const CGFloat *)retinaVerticies
{
    static const GLfloat squareVertices[] =
            {
                    -1.0f, 1.0f,
                    -1.0f, -1.0f,
                    1.0f, 1.0f,
                    1.0f, -1.0f,
            };
    return squareVertices;
}

- (const CGFloat *)nonRetinaVerticies
{
    static const GLfloat squareVertices[] =
            {
                    -1.0f, -1.0f,
                    1.0f, -1.0f,
                    -1.0f, 1.0f,
                    1.0f, 1.0f,
            };
    return squareVertices;
}

- (BOOL)isRetina
{
    return [[UIScreen mainScreen] scale] == 2.0;
}

@end

