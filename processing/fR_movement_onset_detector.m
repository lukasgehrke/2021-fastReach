function [onset_sample] = fR_movement_onset_detector(motion_segment, raw_threshold, pre_raw_window, fine_threshold)
%FR_MOVEMENT_ONSET_DETECTOR

dist = max(motion_segment) - min(motion_segment);
first_thresh = min(motion_segment) + dist*raw_threshold;
movement_detected = min(find(motion_segment>first_thresh));
 
% if size(motion_segment,1) > size(motion_segment,2)
%     motion_segment = motion_segment';
% end

try
    mov_rev = fliplr(motion_segment(movement_detected-pre_raw_window:movement_detected));
    dist = max(mov_rev) - min(mov_rev);
    second_thresh = min(mov_rev) + dist*fine_threshold;

    movement_detected_fine = min(find(mov_rev<second_thresh));
    onset_sample = movement_detected - movement_detected_fine;
catch
    warning('event occurred too early');
    onset_sample = [];

if isempty(onset_sample)
    onset_sample = 0;
end

end

