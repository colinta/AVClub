I've been pouring over the `AVCam` sample code from Apple, and I think I've
finally gotten my head around it enough to generalize it and, I hope, repackage
it for our benefit!

You can setup an AVCaptureSession with video, multiple cameras, and still image
capabilities.  You can also easily have touch-to-focus and flash-on-picture
features.  Just by implementing a few actions and delegate methods.  I'm calling
it "AVClub".

Really, the code is largely unchanged from the sample code - if you've seen it,
I just moved more code into the Manager class, and renamed "AVCamManager" to
"AVClub", since that's the central "wrapper" class.

This tool - and AVFoundation in general - is much more low level than the
UIImagePickerController (see Camera Programming Topics for iOS).  If you're
looking for an easy off-the-shelf solution, use BW::Camera or an instance of
UIImagePickerController.

Working with AVFoundation is like holding a dozen loose wires, plugging them all
into each other, and hoping that a photo or video comes out the end.  If it goes
wrong, lemme know.


The basic process is this:

Create a view for where you want the camera to appear.  Or don't, it's optional.
 If you want to take a picture using the front camera with no preview, you can
 do it!  (creepy! :-P)

1. Create a "club" - `AVClub.new`.
2. Assign your controller as the delegate - `club.delegate = self`.
3. and when you're ready - `startInView(viewfinder_view)`.  You can start and
   stop the session by calling `club.stopSession`

```ruby
def viewDidLoad
  @video_view = UIView.alloc.initWithFrame([[10, 10], [100, 100]])  # an AVCaptureVideoPreviewLayer will be added to this view
  club = AVClub.new
  club.delegate = self
  club.startInView(@video_view)
end
```


For convenience, there is an included `AVClubController` class that adds two
methods you can use or refer to:

```ruby
# this method creates the club, assigns it to self.club, and assigns the
# viewFinderView that you pass to self.viewFinderView
def startInView(view)

# call this in willRotateToInterfaceOrientation(toInterfaceOrientation,
# duration:duration) and pass the new camera frame
def rotateCameraTo(new_frame, orientation:toInterfaceOrientation, duration:duration)
```
