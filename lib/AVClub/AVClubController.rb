class AVClubController < UIViewController
  attr_accessor :club
  attr_accessor :view_finder_view

  def start_in_view(view)
    @view_finder_view = view

    unless @club
      @club = AVClub.new
      @club.delegate = self
      @club.startInView(view)
    end
  end

  def club(club, didFailWithError:error)
      alert_view = UIAlertView.alloc.initWithTitle(error.localizedDescription,
                                           message:error.localizedFailureReason,
                                          delegate:nil,
                                 cancelButtonTitle:'OK',
                                 otherButtonTitles:nil
                                                  )
      alert_view.show
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

  def rotate_camera_to(new_frame, orientation:to_interface_orientation, duration:duration)
    return unless @view_finder_view

    capture_video_preview_layer = nil
    @view_finder_view.layer.sublayers.each do |layer|
      if layer.is_a? AVCaptureVideoPreviewLayer
        capture_video_preview_layer = layer
        break
      end
    end
    return unless capture_video_preview_layer

    case to_interface_orientation
    when UIInterfaceOrientationLandscapeLeft
      rotation = Math::PI / 2
    when UIInterfaceOrientationLandscapeRight
      rotation = -Math::PI / 2
    when UIInterfaceOrientationPortrait
      rotation = 0
    when UIInterfaceOrientationPortraitUpsideDown
      rotation = 2 * Math::PI
    end

    capture_video_preview_layer.masksToBounds = true
    UIView.animateWithDuration(duration, animations:lambda{
      transform = CATransform3DMakeRotation(rotation, 0, 0, 1.0)
      capture_video_preview_layer.anchorPoint = [0.5, 0.5]
      capture_video_preview_layer.transform = transform
      capture_video_preview_layer.frame = new_frame
      # capture_video_preview_layer.orientation = to_interface_orientation
      club.orientation = to_interface_orientation
      NSLog("=============== AVClubController.rb line #{__LINE__} ===============
=============== #{self.class == Class ? self.name + '##' : self.class.name + '#'}#{__method__} ===============
capture_video_preview_layer: #{capture_video_preview_layer.inspect}
capture_video_preview_layer.frame: #{capture_video_preview_layer.frame.inspect}
")
    })
  end

end
