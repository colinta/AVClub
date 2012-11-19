class AVClubController < UIViewController
  attr_accessor :club
  attr_accessor :viewFinderView

  def startInView(view)
    self.viewFinderView = view

    unless club
      self.club = AVClub.new
      self.club.delegate = self
      self.club.startInView(view)
    end
  end

  def club(club, didFailWithError:error)
      alertView = UIAlertView.alloc.initWithTitle(error.localizedDescription,
                                          message:error.localizedFailureReason,
                                         delegate:nil,
                                cancelButtonTitle:'OK',
                                otherButtonTitles:nil
                                                 )
      alertView.show
  end

  def club(club, stillImageCaptured:image, error:error)
  end

  def club(club, assetSavedToURL:url, error:error)
  end

  def clubRecordingBegan(club)
  end

  def clubRecordingFinished(club)
  end

  def clubDeviceConfigurationChanged(club)
  end

  def rotateCameraTo(new_frame, orientation:toInterfaceOrientation, duration:duration)
    return unless viewFinderView

    captureVideoPreviewLayer = nil
    viewFinderView.layer.sublayers.each do |layer|
      if layer.is_a? AVCaptureVideoPreviewLayer
        captureVideoPreviewLayer = layer
        break
      end
    end
    return unless captureVideoPreviewLayer

    case toInterfaceOrientation
    when UIInterfaceOrientationLandscapeLeft
      rotation = Math::PI / 2
    when UIInterfaceOrientationLandscapeRight
      rotation = -Math::PI / 2
    when UIInterfaceOrientationPortrait
      rotation = 0
    when UIInterfaceOrientationPortraitUpsideDown
      rotation = 2 * Math::PI
    end

    captureVideoPreviewLayer.masksToBounds = true
    UIView.animateWithDuration(duration, animations:lambda{
      captureVideoPreviewLayer.frame = new_frame
      captureVideoPreviewLayer.orientation = toInterfaceOrientation
    })
  end
end
