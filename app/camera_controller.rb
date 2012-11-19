class CameraController < AVClubController
  attr_accessor :record_button, :still_button, :toggle_button;

  def viewDidLoad
    super
    self.view.backgroundColor = UIColor.darkGrayColor

    self.viewFinderView = UIView.alloc.initWithFrame(UIEdgeInsetsInsetRect(self.view.bounds, [50, 20, 20, 20]))
    self.viewFinderView.autoresizingMask = UIViewAutoresizingFlexibleHeight |
                                             UIViewAutoresizingFlexibleWidth
    self.viewFinderView.backgroundColor = UIColor.lightGrayColor
    self.view.addSubview(self.viewFinderView)

    ### important ###
    startInView(self.viewFinderView)

    width = 0
    height = 0
    self.toggle_button = UIButton.buttonWithType(UIButtonTypeRoundedRect).tap do |button|
      button.setTitle('Camera', forState:UIControlStateNormal)
      button.sizeToFit
      width += CGRectGetWidth(button.frame)
      height = CGRectGetHeight(button.frame)

      button.addTarget(self, action: 'toggleCamera:', forControlEvents:UIControlEventTouchUpInside)
    end
    width += 10

    self.record_button = UIButton.buttonWithType(UIButtonTypeRoundedRect).tap do |button|
      button.setTitle('Record', forState:UIControlStateNormal)
      button.sizeToFit
      width += CGRectGetWidth(button.frame)

      button.addTarget(self, action: 'toggleRecording:', forControlEvents:UIControlEventTouchUpInside)
    end
    width += 10

    self.still_button = UIButton.buttonWithType(UIButtonTypeRoundedRect).tap do |button|
      button.setTitle('Photo', forState:UIControlStateNormal)
      button.sizeToFit
      width += CGRectGetWidth(button.frame)

      button.addTarget(self, action: 'captureStillImage:', forControlEvents:UIControlEventTouchUpInside)
    end

    left = (CGRectGetWidth(self.view.frame) - width) / 2.0
    top = 5
    buttons_view = UIView.alloc.initWithFrame([[left, top], [width, height]])
    buttons_view.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                    UIViewAutoresizingFlexibleTopMargin |
                                    UIViewAutoresizingFlexibleRightMargin |
                                    UIViewAutoresizingFlexibleBottomMargin

    left = 0
    top = 0
    self.toggle_button.frame = [[left, top], self.toggle_button.frame.size]
    left += CGRectGetWidth(self.toggle_button.frame) + 10
    self.record_button.frame = [[left, top], self.record_button.frame.size]
    left += CGRectGetWidth(self.record_button.frame) + 10
    self.still_button.frame = [[left, top], self.still_button.frame.size]
    left += CGRectGetWidth(self.still_button.frame) + 10

    buttons_view.addSubview(self.toggle_button)
    buttons_view.addSubview(self.record_button)
    buttons_view.addSubview(self.still_button)

    self.view.addSubview(buttons_view)

    self.update_button_states

    # Add a single tap gesture to focus on the point tapped, then lock focus
    singleTap = UITapGestureRecognizer.alloc.initWithTarget(self, action:'tapToAutoFocus:')
    singleTap.setDelegate(self)
    singleTap.setNumberOfTapsRequired(1)
    self.viewFinderView.addGestureRecognizer(singleTap)
  end

  # Auto focus at a particular point. The focus mode will change to locked once
  # the auto focus happens.
  def tapToAutoFocus(gestureRecognizer)
    return unless club.videoInput

    if club.videoInput.device.isFocusPointOfInterestSupported
      tapPoint = gestureRecognizer.locationInView(viewFinderView)
      convertedFocusPoint = club.convertToPointOfInterestFromViewCoordinates(tapPoint)
      club.autoFocusAtPoint(convertedFocusPoint)
    end
  end

  # Change to continuous auto focus. The camera will constantly focus at the
  # point choosen.
  def tapToContinouslyAutoFocus(gestureRecognizer)
    return unless club.videoInput

    if club.videoInput.device.isFocusPointOfInterestSupported
      club.continuousFocusAtPoint(CGPoint.new(0.5, 0.5))
    end
  end

  def toggleCamera(sender)
    # Toggle between cameras when there is more than one
    club.toggleCamera

    # Do an initial focus
    club.continuousFocusAtPoint(CGPoint.new(0.5, 0.5))
  end

  def toggleRecording(sender)
    # Start recording if there isn't a recording running. Stop recording if there is.
    record_button.setEnabled(false)
    unless club.recorder.isRecording
      club.startRecording
    else
      club.stopRecording
    end
  end

  def captureStillImage(sender)
    return unless still_button.isEnabled

    # Capture a still image
    still_button.setEnabled(false)
    club.captureStillImageAnimated(true)
  end

  def update_button_states
    if club.cameraCount > 1
      self.toggle_button.enabled = true
      self.record_button.enabled = true
      self.still_button.enabled = true
    else
      self.toggle_button.enabled = false

      if club.cameraCount > 0
        self.record_button.enabled = true
        self.still_button.enabled = true
      else
        self.still_button.enabled = false

        if club.micCount > 0
          self.record_button = true
        else
          self.record_button = false
        end
      end
    end
  end

  def clubRecordingBegan(club)
    self.record_button.setTitle('Stop', forState:UIControlStateNormal)
    update_button_states
  end

  def clubRecordingFinished(club)
    self.record_button.setTitle('Record', forState:UIControlStateNormal)
    update_button_states
  end

  def club(club, stillImageCaptured:image, error:error)
    if image
      club.saveImageToLibrary(image)
    else
      update_button_states
    end
  end

  def club(club, assetSavedToURL:image, error:error)
    update_button_states
  end

  def clubDeviceConfigurationChanged(club)
    update_button_states
  end

  def willRotateToInterfaceOrientation(toInterfaceOrientation, duration:duration)
    super

    case toInterfaceOrientation
    when UIInterfaceOrientationLandscapeLeft
      new_frame = CGRect.new([0, 0], [480, 320])
    when UIInterfaceOrientationLandscapeRight
      new_frame = CGRect.new([0, 0], [480, 320])
    when UIInterfaceOrientationPortrait
      new_frame = CGRect.new([0, 0], [320, 480])
    when UIInterfaceOrientationPortraitUpsideDown
      new_frame = CGRect.new([0, 0], [320, 480])
    end

    ### important ###
    rotateCameraTo(new_frame, orientation:toInterfaceOrientation, duration:duration)
  end

end
