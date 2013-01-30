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
`UIImagePickerController` (see Camera Programming Topics for iOS).  If you're
looking for an easy off-the-shelf solution, use `BubbleWrap::Camera` or an
instance of `UIImagePickerController`.

Working with AVFoundation is like holding a dozen loose wires, plugging them all
into each other, and hoping that a photo or video comes out the end.  If it goes
wrong, lemme know.


The basic process is this:

Create a view-finder, for where you want the preview image to appear.  Or don't,
it's optional.

1. Create a "club" - `AVClub.new`.
2. Assign your controller as the delegate - `club.delegate = self`.
3. When you're ready, pass the view-finder to AVClub:
   `club.startInView(viewfinder_view)`.  You can start and stop the session by
   calling `club.stopSession ; club.startSession`

```ruby
def viewDidLoad
  @video_view = UIView.alloc.initWithFrame([[10, 10], [100, 100]])  # an AVCaptureVideoPreviewLayer will be added to this view
  club = AVClub.new
  club.delegate = self
  club.startInView(@video_view)
end
```

You might have noticed that AVClub uses `camelCased` method names, rather than
the more rubyesque `snake_case`.  This is to distinguish it as an *Objective-C*
class.  *However*, for convenience, there is an included `AVClubController`
class that is a *Ruby* class, and so uses `snake_case`. It adds two methods you
can use or refer to: `start_in_view(viewfinder)` (it just passes it on to the
`AVClub` object, `@club`) and `rotate_camera_to(orientation:duration:)`.

```ruby
# this method creates the club, assigns it to self.club, and assigns the
# viewFinderView that you pass to self.viewFinderView
def viewWillAppear(animated)
  self.start_in_view(view)
end

# you have to tell AVClub to rotate the image using rotate_camera_to()
def willRotateToInterfaceOrientation(to_interface_orientation, duration:duration)
  # you'll need to adjust the frame yourself!

  case to_interface_orientation
  when UIInterfaceOrientationLandscapeLeft
    new_frame = CGRect.new([0, 0], [480, 320])
  when UIInterfaceOrientationLandscapeRight
    new_frame = CGRect.new([0, 0], [480, 320])
  when UIInterfaceOrientationPortrait
    new_frame = CGRect.new([0, 0], [320, 480])
  when UIInterfaceOrientationPortraitUpsideDown
    new_frame = CGRect.new([0, 0], [320, 480])
  end

  rotate_camera_to(new_frame, orientation: to_interface_orientation, duration:duration)
end
```
