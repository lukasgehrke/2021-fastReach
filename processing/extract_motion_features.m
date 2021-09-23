function [sp] = extract_motion_features(events, motion, event_str, epoch, buffer)
%EXTRACT_MOTION_FEATURES

%% detect motion onset samples to build pre-movement class

motion.data(1,:) = sqrt(motion.data(4,:).^2 + motion.data(5,:).^2 + motion.data(6,:).^2);
motion = pop_epoch( motion, {event_str}, epoch);

sp.mag = squeeze(motion.data(1,:,:));

for i = 1:size(sp.mag,2)
    
    if buffer
        sp.onset_sample(i) = fR_movement_onset_detector(sp.mag(buffer:end,i), .7, 125, .05);
        sp.onset_sample(i) = sp.onset_sample(i) + buffer;        
    else
        sp.onset_sample(i) = fR_movement_onset_detector(sp.mag(:,i), .7, 125, .05);
    end 
end

end

