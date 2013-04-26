iOSFBOToAVAssetWriterTextureCacheSpike
======================================

example of how to write out opengles FBO to avasset writer using ios's fast texture cache - same thing used by gpuimage

Based on this post here:
http://allmybrain.com/2011/12/08/rendering-to-a-texture-with-ios-5-texture-cache-api/

The technique allows for very fast rendering as used by GPUImage..

Project is currently Broken - looking for help to fix it.. 

Working:
create contexts,
create basic drawing primitives to draw a texture,
has own context and own methods for drawing to screen to aid debugging,
create FBO compliant with the requirements in the blog post,
AVAssetWriter setup,
tap to start, tap to stop,
writes out movie, saves to asset library

Not working:
anything rendered in the fbo does not get displayed in the movie.
I know the FBO is getting saved because I can change the fbo clear color and it changes the color of the movie correspondingly.

Note - project is called GreenScreen as I simplified it from a spike I made for mixing green screen movies, which was based on a sample by Erik M. Buck’s code, available from http://www.informit.com/articles/article.aspx?p=1946398.